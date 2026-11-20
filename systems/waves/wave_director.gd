## Runs the round loop: intermission -> round start -> spawning ->
## clearing -> round end -> intermission. Reads every number from WaveRules
## and asks the Spawner for enemies; never creates them itself. Only the
## server runs the loop; clients get each round event and a snapshot on join.
class_name WaveDirector
extends Node

enum Phase { IDLE, INTERMISSION, SPAWNING, CLEARING }
enum Message { STARTED, ENDED, INTERMISSION, BLACKOUT }

## The last LAST_FEW zombies of a round sprint after LAST_FEW_TIME seconds (zombie-ai.md).
const LAST_FEW: int = 2
const LAST_FEW_TIME: float = 30.0

@export var rules: WaveRules
@export var spawner: Spawner

var phase: Phase = Phase.IDLE
var round_number: int = 0
var to_spawn: int = 0
var total_kills: int = 0
## The lights are out (a Blackout round). The server decides; every peer gets it with each round message.
var blackout: bool = false
var session: GameSession
var _timer: float = 0.0
var _last_few_time: float = 0.0


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	multiplayer.connected_to_server.connect(_ask_round_state)
	if not multiplayer.is_server():
		_ask_round_state.call_deferred()


func start() -> void:
	if not Net.is_authority():
		return
	round_number = 0
	_begin_intermission(rules.first_round_delay)


func stop() -> void:
	phase = Phase.IDLE


## Debug/console helper.
func skip_to_round(n: int) -> void:
	round_number = n - 1
	_begin_round()


## Server: turns the lights out or back on for every peer.
func set_blackout(on: bool) -> void:
	if not multiplayer.is_server():
		return
	_apply_blackout(on)
	_relay(Message.BLACKOUT, 0.0)


func _apply_blackout(on: bool) -> void:
	if on == blackout:
		return
	blackout = on
	if on:
		Events.blackout_started.emit(round_number)
	else:
		Events.blackout_ended.emit(round_number)


func _physics_process(delta: float) -> void:
	if phase == Phase.IDLE or not _runs_loop():
		return
	match phase:
		Phase.INTERMISSION:
			_timer -= delta
			if _timer <= 0.0:
				_begin_round()
		Phase.SPAWNING:
			_timer -= delta
			if _timer <= 0.0 and spawner.alive_count() < rules.get_max_alive(_player_count()):
				_timer = rules.get_spawn_interval(round_number)
				spawner.spawn(rules.pick_enemy(round_number, session.rng), round_number, rules)
				to_spawn -= 1
				if to_spawn <= 0:
					phase = Phase.CLEARING
					_check_round_end()
		Phase.CLEARING:
			_tick_last_few(delta)


## Counts time while only the last few zombies are left, then hurries them once.
func _tick_last_few(delta: float) -> void:
	var alive: int = spawner.alive_count()
	if alive == 0 or alive > LAST_FEW or _last_few_time >= LAST_FEW_TIME:
		return
	_last_few_time += delta
	if _last_few_time >= LAST_FEW_TIME and not rules.speed_tiers.is_empty():
		for zombie: Zombie in spawner.zombies:
			if zombie.state != Zombie.State.DEAD:
				zombie.hurry(rules.speed_tiers[rules.speed_tiers.size() - 1])


func _begin_intermission(duration: float) -> void:
	phase = Phase.INTERMISSION
	_timer = duration
	Events.intermission_started.emit(round_number + 1, duration)
	_relay(Message.INTERMISSION, duration)


func _begin_round() -> void:
	round_number += 1
	to_spawn = rules.get_enemy_count(round_number, _player_count())
	_last_few_time = 0.0
	_timer = 0.5
	phase = Phase.SPAWNING
	Events.round_started.emit(round_number, to_spawn)
	_relay(Message.STARTED, to_spawn)


func _on_enemy_killed(_enemy: Node3D, _info: DamageInfo) -> void:
	total_kills += 1
	if phase == Phase.CLEARING:
		_check_round_end.call_deferred()


func _check_round_end() -> void:
	if phase != Phase.CLEARING or spawner.alive_count() > 0:
		return
	Events.round_ended.emit(round_number)
	_relay(Message.ENDED, 0.0)
	_begin_intermission(rules.intermission_time)


func _player_count() -> int:
	return maxi(get_tree().get_nodes_in_group(&"players").size(), 1)


func _relay(kind: Message, value: float) -> void:
	if is_inside_tree() and _runs_loop() and not multiplayer.get_peers().is_empty():
		_receive_round.rpc(kind, round_number, value, blackout)


@rpc("authority", "call_remote", "reliable")
func _receive_round(kind: int, number: int, value: float, server_blackout: bool) -> void:
	if not _from_server():
		return
	round_number = number
	if kind != Message.ENDED:
		_apply_blackout(server_blackout)
	match kind:
		Message.STARTED:
			phase = Phase.SPAWNING
			Events.round_started.emit(number, int(value))
		Message.ENDED:
			phase = Phase.CLEARING
			Events.round_ended.emit(number)
			_apply_blackout(server_blackout)
		Message.INTERMISSION:
			phase = Phase.INTERMISSION
			Events.intermission_started.emit(number + 1, value)


func _ask_round_state() -> void:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if is_inside_tree() and peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_request_round_state.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_round_state() -> void:
	if multiplayer.is_server():
		var sender: int = multiplayer.get_remote_sender_id()
		_receive_round_state.rpc_id(sender, phase, round_number, maxf(_timer, 0.0), blackout)


## Late joiner: catch the HUD and music up with the round in progress.
@rpc("authority", "call_remote", "reliable")
func _receive_round_state(server_phase: int, number: int, time_left: float, server_blackout: bool) -> void:
	if not _from_server():
		return
	phase = server_phase as Phase
	round_number = number
	_apply_blackout(server_blackout)
	if phase == Phase.INTERMISSION:
		Events.intermission_started.emit(number + 1, time_left)
	elif phase != Phase.IDLE:
		Events.round_started.emit(number, 0)


## A closed peer (match over, server gone) runs nothing and asks nothing.
func _runs_loop() -> bool:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	return multiplayer.is_server()


func _from_server() -> bool:
	if multiplayer.get_remote_sender_id() == 1 and not multiplayer.is_server():
		return true
	Log.warn(&"net", &"round_state_ignored", {"sender": multiplayer.get_remote_sender_id()})
	return false

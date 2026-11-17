## Co-op soak server: a real dedicated server whose players cannot die, with power on and doors open
## (like soak_run.gd). Rewrites its JSON result each round; quits once the bots leave after the target round.
extends DedicatedServer

const RUN: GDScript = preload("res://tools/soak/coop_soak.gd")
const LEAVE_WAIT_MS: int = 20000

var _rounds: int = 5
var _result_path: String = ""
var _round: int = 0
var _kills: int = 0
var _players: int = 0
var _done_at: int = -1


func _ready() -> void:
	Engine.time_scale = float(RUN.arg("timescale"))
	Engine.max_fps = Engine.physics_ticks_per_second
	_rounds = int(RUN.arg("rounds"))
	_result_path = RUN.arg("result")
	super()
	if session == null:
		return
	session.rng_seed = int(RUN.arg("seed"))
	session.ready.connect(_open_map)
	Events.round_ended.connect(_on_round_ended)
	Events.enemy_killed.connect(func(_enemy: Node3D, _info: DamageInfo) -> void: _kills += 1)
	_write(false)


func _open_map() -> void:
	session.level.turn_power_on()
	for door: Door in get_tree().get_nodes_in_group(&"doors"):
		door.open()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(session) or not session.is_node_ready():
		return
	var players: Array[Player] = session.get_players()
	_players = maxi(_players, players.size())
	for player: Player in players:
		if player.health.max_health != INF:
			player.health.reset(INF)
	if _done_at >= 0 and (multiplayer.get_peers().is_empty() or Time.get_ticks_msec() - _done_at > LEAVE_WAIT_MS):
		set_physics_process(false)
		get_tree().quit()


func _on_round_ended(round_number: int) -> void:
	_round = round_number
	if round_number >= _rounds and _done_at < 0:
		_done_at = Time.get_ticks_msec()
	_write(_done_at >= 0)


func _write(done: bool) -> void:
	var data: Dictionary = {"role": "server", "done": done, "round": _round, "kills": _kills, "players": _players}
	data["log"] = ProjectSettings.globalize_path(Log.log_path)
	RUN.write_result(_result_path, data)

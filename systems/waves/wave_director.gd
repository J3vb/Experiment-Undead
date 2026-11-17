## Runs the round loop: intermission -> round start -> spawning ->
## clearing -> round end -> intermission. Reads every number from WaveRules
## and asks the Spawner for enemies; never creates them itself.
class_name WaveDirector
extends Node

enum Phase { IDLE, INTERMISSION, SPAWNING, CLEARING }

## The last LAST_FEW zombies of a round sprint after LAST_FEW_TIME seconds (zombie-ai.md).
const LAST_FEW: int = 2
const LAST_FEW_TIME: float = 30.0

@export var rules: WaveRules
@export var spawner: Spawner

var phase: Phase = Phase.IDLE
var round_number: int = 0
var to_spawn: int = 0
var total_kills: int = 0
var session: GameSession
var _timer: float = 0.0
var _last_few_time: float = 0.0


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)


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


func _physics_process(delta: float) -> void:
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


func _begin_round() -> void:
	round_number += 1
	to_spawn = rules.get_enemy_count(round_number, _player_count())
	_last_few_time = 0.0
	_timer = 0.5
	phase = Phase.SPAWNING
	Events.round_started.emit(round_number, to_spawn)


func _on_enemy_killed(_enemy: Node3D, _info: DamageInfo) -> void:
	total_kills += 1
	if phase == Phase.CLEARING:
		_check_round_end.call_deferred()


func _check_round_end() -> void:
	if phase != Phase.CLEARING or spawner.alive_count() > 0:
		return
	Events.round_ended.emit(round_number)
	_begin_intermission(rules.intermission_time)


func _player_count() -> int:
	return maxi(get_tree().get_nodes_in_group(&"players").size(), 1)

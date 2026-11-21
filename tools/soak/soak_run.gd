## Runs real waves with a stationary immortal player and authority-side hits after zombie entry.
## With --fight 1 the player is mortal and the balance bot shoots with real guns instead.
extends Node

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const REPORT: GDScript = preload("res://tools/soak/soak.gd")
const BOT: GDScript = preload("res://tools/soak/soak_bot.gd")
const LIMIT_MS: int = 600000
const KILL_EVERY_TICKS: int = 30

var _rounds: int = 10
var _seed: int = 1
var _timescale: float = 4.0
var _fight: bool = false
var _wall: StringName = &""
var _died_in: int = 0
var _bot: Node
var _session: GameSession
var _player: Player
var _started: int = 0
var _ticks: int = 0
var _finished: bool = false


func _ready() -> void:
	_started = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if not _parse_args():
		get_tree().quit(1)
		return
	Engine.time_scale = _timescale
	Engine.max_fps = Engine.physics_ticks_per_second
	_session = SESSION.instantiate() as GameSession
	_session.profile_id = &""
	_session.rng_seed = _seed
	get_tree().root.add_child(_session)
	get_tree().current_scene = _session
	_session.rng.seed = _seed
	_player = _session.get_players()[0]
	_player.local_input.enabled = false
	_player.set_physics_process(false)
	if _fight:
		_bot = BOT.new()
		add_child(_bot)
		_bot.setup(_player, _wall)
		_player.abilities.ability = Content.get_item(&"abilities", &"shock_pulse") as AbilityData
		Events.player_died.connect(_on_player_died)
	else:
		_player.input_enabled = false
		_player.health.reset(INF)
	_session.level.turn_power_on()
	for door: Door in get_tree().get_nodes_in_group(&"doors"):
		door.open()
	Events.round_ended.connect(_on_round_ended)


func _parse_args() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() % 2 != 0:
		return _argument_error("expected pairs: --rounds N --seed N --timescale N --fight 0|1 --wall ID")
	for index: int in range(0, args.size(), 2):
		if not _parse_argument(args[index], args[index + 1]):
			return false
	return true


func _parse_argument(option: String, value: String) -> bool:
	match option:
		"--rounds":
			if not value.is_valid_int() or int(value) < 1:
				return _argument_error("--rounds must be a positive integer")
			_rounds = int(value)
		"--seed":
			if not value.is_valid_int():
				return _argument_error("--seed must be an integer")
			_seed = int(value)
		"--timescale":
			return _set_timescale(value)
		"--fight":
			return _set_fight(value)
		"--wall":
			_wall = StringName(value)
		_:
			return _argument_error("unknown argument: " + option)
	return true


func _set_fight(value: String) -> bool:
	if value not in ["0", "1"]:
		return _argument_error("--fight must be 0 or 1")
	_fight = value == "1"
	return true


func _set_timescale(value: String) -> bool:
	if not value.is_valid_float() or not is_finite(float(value)) or float(value) <= 0.0:
		return _argument_error("--timescale must be positive and finite")
	_timescale = float(value)
	return true


func _argument_error(message: String) -> bool:
	printerr("Soak: ", message)
	return false


func _process(_delta: float) -> void:
	if not _finished and Time.get_ticks_msec() - _started >= LIMIT_MS:
		_finish()


func _physics_process(_delta: float) -> void:
	if _finished or _fight or _session == null or not Net.is_authority():
		return
	_ticks += 1
	if _ticks % KILL_EVERY_TICKS != 0:
		return
	for zombie: Zombie in get_tree().get_nodes_in_group(&"enemies"):
		if zombie.health.is_dead or zombie.barrier != null:
			continue
		if zombie.state not in [Zombie.State.CHASING, Zombie.State.ATTACKING]:
			continue
		var info: DamageInfo = DamageInfo.create(zombie.health.current, _player)
		info.position = zombie.global_position
		zombie.hit_zones[1].receive_hit(info)
		return


func _on_player_died(_dead: Player) -> void:
	_died_in = _session.director.round_number
	_finish()


func _on_round_ended(round_number: int) -> void:
	if round_number >= _rounds:
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_report.call_deferred()


func _report() -> void:
	var kills: int = _session.director.total_kills
	var points: int = _player.wallet.points
	var gun: StringName = _player.weapons.current.data.id
	_session.director.stop()
	_session.free()
	await get_tree().process_frame
	var result: Dictionary = REPORT.check_log(Log.log_path, _died_in - 1 if _died_in > 0 else _rounds)
	var seconds: float = (Time.get_ticks_msec() - _started) / 1000.0
	var status: String = "FAIL" if result["failed"] else "PASS"
	print("| Result | Rounds reached | Rounds completed | Kills | Points | Run time (real s) |")
	print("| --- | --- | --- | --- | --- | --- |")
	print(
		"| %s | %d | %d | %d | %d | %.1f |" % [status, result["reached"], result["completed"], kills, points, seconds]
	)
	print("")
	print("| Severity / event | Count | First log line |")
	print("| --- | --- | --- |")
	if result.has("reason"):
		print("| FAIL: %s | 1 | — |" % result["reason"])
	for key: String in result["problems"]:
		var problem: Dictionary = result["problems"][key]
		var first: String = str(problem["first"]).replace("|", "&#124;").replace("`", "&#96;")
		print(
			(
				"| %s: %s | %d | line %d: `%s` |"
				% ["FAIL" if problem["fails"] else "WARN", key, problem["count"], problem["line"], first]
			)
		)
	if _fight:
		var fate: String = "died in round %d" % _died_in if _died_in > 0 else "survived"
		print("| Bot | %s | hunted %d | gun %s |" % [fate, _bot.hunts, gun])
	print("Soak log: ", ProjectSettings.globalize_path(Log.log_path))
	get_tree().quit(1 if result["failed"] else 0)

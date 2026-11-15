## Headless CPU benchmark of normal physics callbacks; run with -- --zombies 24 --seconds 20 --seed 1.
## Includes movement/navigation queries, excludes rendering, idle callbacks and standalone physics-server integration.
extends Node

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const WARMUP_SECONDS: float = 2.0

var _zombies: int = 24
var _seconds: float = 20.0
var _seed: int = 1
var _session: GameSession
var _samples: Array[float] = []
var _warmup_ticks: int = 0
var _measurement_ticks: int = 0
var _elapsed_ticks: int = 0
var _tick_start: int = 0
var _finished: bool = false


class PhysicsEnd:
	extends Node
	signal tick_ended(ended_usec: int)

	func _physics_process(_delta: float) -> void:
		tick_ended.emit(Time.get_ticks_usec())


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _parse_args():
		get_tree().quit(0)
		return
	Engine.max_fps = Engine.physics_ticks_per_second
	_warmup_ticks = ceili(WARMUP_SECONDS * Engine.physics_ticks_per_second)
	_measurement_ticks = ceili(_seconds * Engine.physics_ticks_per_second)
	_session = SESSION.instantiate() as GameSession
	_session.profile_id = &""
	_session.rng_seed = _seed
	_session.get_node("WaveDirector").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_session)
	get_tree().current_scene = _session
	# Assign again so seed 0 is repeatable too (GameSession normally randomizes 0).
	_session.rng.seed = _seed
	for player: Player in _session.get_players():
		player.input_enabled = false
		player.local_input.enabled = false
		player.health.reset(INF)
	var deadline: int = Time.get_ticks_msec() + 30000
	while not _session.level.is_navigation_ready:
		if Time.get_ticks_msec() > deadline:
			_fail("navigation did not become ready within 30 seconds")
			return
		await get_tree().process_frame
	_session.director.stop()
	for _index: int in _zombies:
		var enemy: EnemyData = _session.wave_rules.pick_enemy(1, _session.rng)
		if _session.spawner.spawn(enemy, 1, _session.wave_rules) == null:
			_fail("Spawner could not create a zombie")
			return
	var end: PhysicsEnd = PhysicsEnd.new()
	end.process_physics_priority = 2147483647
	end.tick_ended.connect(_end_tick)
	get_tree().root.add_child(end)
	get_tree().physics_frame.connect(_begin_tick)


func _parse_args() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() % 2 != 0:
		_fail("expected pairs: --zombies N --seconds N --seed N")
		return false
	for index: int in range(0, args.size(), 2):
		var value: String = args[index + 1]
		match args[index]:
			"--zombies":
				if not value.is_valid_int() or int(value) < 1:
					return _argument_error("--zombies must be a positive integer")
				_zombies = int(value)
			"--seconds":
				if not value.is_valid_float() or not is_finite(float(value)) or float(value) <= 0.0:
					return _argument_error("--seconds must be a positive finite number")
				_seconds = float(value)
			"--seed":
				if not value.is_valid_int():
					return _argument_error("--seed must be an integer")
				_seed = int(value)
			_:
				return _argument_error("unknown argument: %s" % args[index])
	return true


func _argument_error(message: String) -> bool:
	_fail(message)
	return false


func _begin_tick() -> void:
	_tick_start = Time.get_ticks_usec()


func _end_tick(ended_usec: int) -> void:
	if _finished:
		return
	_elapsed_ticks += 1
	if _elapsed_ticks <= _warmup_ticks:
		return
	_samples.append((ended_usec - _tick_start) / 1000.0)
	if _samples.size() == _measurement_ticks:
		_finished = true
		_report.call_deferred()


func _report() -> void:
	var sorted: Array[float] = _samples.duplicate()
	sorted.sort()
	var total: float = 0.0
	for sample: float in sorted:
		total += sample
	var result: Dictionary = {
		"status": "ok",
		"zombies": _zombies,
		"spawned_zombies": _session.spawner.get_child_count(),
		"alive_zombies": _session.spawner.alive_count(),
		"player_alive": _session.get_players()[0].is_alive(),
		"seed": _seed,
		"seconds": _seconds,
		"warmup_seconds": WARMUP_SECONDS,
		"physics_hz": Engine.physics_ticks_per_second,
		"sample_count": sorted.size(),
		"metric": "physics_callbacks_cpu_ms",
		"scope": "physics callbacks including movement/nav queries; excludes render, idle and server integration",
		"godot_version": Engine.get_version_info()["string"],
		"cpu": OS.get_processor_name(),
		"average_ms": total / sorted.size(),
		"p95_ms": sorted[ceili(sorted.size() * 0.95) - 1],
		"p99_ms": sorted[ceili(sorted.size() * 0.99) - 1],
		"max_ms": sorted[-1],
		"samples_ms": _samples,
	}
	if result["alive_zombies"] != _zombies or not result["player_alive"]:
		result["status"] = "error"
		result["error"] = "population changed or player died; measurement is invalid"
	print("\nHeadless CPU physics callbacks (no GPU; not measured rendering FPS)")
	print("Reference budgets: 120 fps = 8.333 ms; 90 fps = 11.111 ms. Physics remains at 60 Hz.")
	print("| Zombies | Samples | Average ms | P95 ms | P99 ms | Max ms |")
	print("| --- | --- | --- | --- | --- | --- |")
	print(
		(
			"| %d | %d | %.3f | %.3f | %.3f | %.3f |"
			% [_zombies, sorted.size(), result["average_ms"], result["p95_ms"], result["p99_ms"], result["max_ms"]]
		)
	)
	_write_result(result)
	get_tree().quit(0)


func _fail(message: String) -> void:
	print("Benchmark error: ", message)
	_write_result({"status": "error", "zombies": _zombies, "seed": _seed, "error": message})
	get_tree().quit(0)


func _write_result(result: Dictionary) -> void:
	var path: String = "user://benchmark_%d.json" % _zombies
	var absolute: String = ProjectSettings.globalize_path(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("Benchmark error: could not write ", absolute, " (", FileAccess.get_open_error(), ")")
		return
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.close()
	print("Benchmark JSON: ", absolute)

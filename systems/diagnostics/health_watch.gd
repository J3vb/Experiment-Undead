## Watches for early warning signs while the game runs: long frames, low fps,
## growing orphan nodes and rounds that stop progressing. Writes a "health"
## sample to the Log every SAMPLE_SECONDS. Child of the Log autoload.
class_name HealthWatch
extends Node

## One frame slower than this is a hitch (below 20 fps).
const LONG_FRAME_MS: float = 50.0
## v0.1 target is 60 fps; warn when a whole second is below this.
const LOW_FPS: float = 50.0
## Seconds in a row below LOW_FPS before warning.
const LOW_FPS_SECONDS: int = 3
const SAMPLE_SECONDS: float = 30.0
## Orphan nodes (created but never added or freed) above this are a leak sign.
const ORPHAN_LIMIT: int = 200
## A round with enemies alive and no kill for this long is stalled
## (often one zombie stuck out of reach).
const STALL_SECONDS: float = 90.0

var worst_frame_ms: float = 0.0
var long_frames: int = 0
var min_fps: float = INF
var low_fps_warnings: int = 0

var _second_time: float = 0.0
var _second_frames: int = 0
var _second_long: int = 0
var _second_worst: float = 0.0
var _low_seconds: int = 0
var _sample_time: float = 0.0
var _last_orphans: int = 0
var _in_round: bool = false
var _since_progress: float = 0.0
var _stall_reported: bool = false
var _check_fps: bool = DisplayServer.get_name() != "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.round_started.connect(func(_r: int, _c: int) -> void: _round_progress(true))
	Events.round_ended.connect(func(_r: int) -> void: _in_round = false)
	Events.enemy_killed.connect(func(_e: Node3D, _i: DamageInfo) -> void: _round_progress(_in_round))
	Events.game_over.connect(func(_s: Dictionary) -> void: _in_round = false)


func _process(delta: float) -> void:
	record_frame(delta)
	_sample_time += delta
	if _sample_time >= SAMPLE_SECONDS:
		_sample_time = 0.0
		sample()
	if _in_round and not get_tree().paused:
		check_stall(delta)


## Feeds one rendered frame. Split out of _process so tests can drive it.
func record_frame(delta: float) -> void:
	var ms: float = delta * 1000.0
	if ms > LONG_FRAME_MS:
		_second_long += 1
		long_frames += 1
		_second_worst = maxf(_second_worst, ms)
		worst_frame_ms = maxf(worst_frame_ms, ms)
	_second_frames += 1
	_second_time += delta
	if _second_time >= 1.0:
		_end_second()


func _end_second() -> void:
	var fps: float = _second_frames / _second_time
	if _second_long > 0:
		Log.warn(&"perf", &"long_frames", {"count": _second_long, "worst_ms": snappedf(_second_worst, 0.1)})
	if _check_fps and Engine.get_process_frames() > 120:
		min_fps = minf(min_fps, fps)
		_low_seconds = _low_seconds + 1 if fps < LOW_FPS else 0
		if _low_seconds == LOW_FPS_SECONDS:
			low_fps_warnings += 1
			var data: Dictionary = snapshot()
			data["fps"] = snappedf(fps, 0.1)
			Log.warn(&"perf", &"low_fps", data)
	_second_time = 0.0
	_second_frames = 0
	_second_long = 0
	_second_worst = 0.0


## Writes a health line and warns when orphan nodes keep growing.
func sample() -> void:
	var data: Dictionary = snapshot()
	Log.info(&"perf", &"health", data)
	var orphans: int = data["orphan_nodes"]
	if orphans > ORPHAN_LIMIT and orphans > _last_orphans:
		Log.warn(&"perf", &"orphan_nodes_growing", {"orphan_nodes": orphans, "previous": _last_orphans})
	_last_orphans = orphans
	Log.write_summary(false)


func snapshot() -> Dictionary:
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
		"physics_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
		"memory_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"enemies": get_tree().get_node_count_in_group(&"enemies"),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
	}


func report() -> Dictionary:
	return {
		"worst_frame_ms": snappedf(worst_frame_ms, 0.1),
		"long_frames": long_frames,
		"min_fps": snappedf(min_fps, 0.1) if min_fps != INF else -1.0,
		"low_fps_warnings": low_fps_warnings,
	}


func _round_progress(in_round: bool) -> void:
	_in_round = in_round
	_since_progress = 0.0
	_stall_reported = false


func check_stall(delta: float) -> void:
	_since_progress += delta
	if _stall_reported or _since_progress < STALL_SECONDS:
		return
	_stall_reported = true
	var where: Array[String] = []
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var zombie: Zombie = node as Zombie
		if zombie and zombie.state != Zombie.State.DEAD and where.size() < 8:
			where.append("%s %s" % [zombie.net_id, zombie.global_position.snappedf(0.1)])
	Log.warn(&"waves", &"round_stalled", {"seconds_without_kill": int(_since_progress), "enemies_alive": where})

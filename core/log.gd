## Structured game log for people and AI agents: one JSON object per line in
## user://logs/run_<time>_<role>.jsonl, plus a .summary.json next to it that is
## rewritten every health sample and on exit. Engine errors and warnings are
## captured too. How to read them: docs/LOGGING.md.
extends Node

const DIR: String = "user://logs"
## Older runs beyond this are deleted at start.
const KEEP_RUNS: int = 20
## Distinct warnings/errors kept in the summary.
const MAX_PROBLEMS: int = 40

var session_id: String = ""
var log_path: String = ""
var round_number: int = 0
var max_round: int = 0
## Lines written per level ("info", "warn", "error").
var level_counts: Dictionary[String, int] = {}
## Lines written per "system.event".
var event_counts: Dictionary[String, int] = {}
## One entry per distinct warning/error: first line seen + how often.
var problems: Dictionary[String, Dictionary] = {}
var health: HealthWatch

var _file: FileAccess
var _mutex: Mutex = Mutex.new()
var _capture: EngineErrorCapture
var _peer: int = 1
var _started_unix: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var role: String = "server" if Build.is_server() else "client"
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	# The process id keeps two runs started in the same second apart.
	open("%s/run_%s_%s_%d.jsonl" % [DIR, stamp, role, OS.get_process_id()])
	prune_old_runs(DIR, KEEP_RUNS)
	_capture = EngineErrorCapture.new(self)
	OS.add_logger(_capture)
	health = HealthWatch.new()
	add_child(health)
	info(&"build", &"run_started", _run_info(role))
	if Build.crashed_last_run:
		warn(&"build", &"previous_run_crashed", {"previous_log": _previous_log()})
	_connect_events()
	# A crash during loading still leaves a summary that says clean_exit: false.
	write_summary(false)


func _exit_tree() -> void:
	info(&"build", &"run_ended", {"seconds": snappedf(Time.get_unix_time_from_system() - _started_unix, 0.1)})
	write_summary(true)
	if _capture:
		OS.remove_logger(_capture)
	_file = null


func _process(_delta: float) -> void:
	_peer = multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1


func info(system: StringName, event: StringName, data: Dictionary = {}) -> void:
	write("info", system, event, data)


## Something looks wrong but the game goes on. These are the early warnings.
func warn(system: StringName, event: StringName, data: Dictionary = {}) -> void:
	write("warn", system, event, data)


## Something broke: a rule was violated or a feature cannot work.
func error(system: StringName, event: StringName, data: Dictionary = {}) -> void:
	write("error", system, event, data)


## Safe to call from any thread.
func write(level: String, system: StringName, event: StringName, data: Dictionary) -> void:
	var line: Dictionary = {
		"time": Time.get_datetime_string_from_system(true),
		"up_ms": Time.get_ticks_msec(),
		"frame": Engine.get_process_frames(),
		"level": level,
		"system": String(system),
		"event": String(event),
		"round": round_number,
		"peer": _peer,
		"session": session_id,
		"data": data,
	}
	var text: String = JSON.stringify(line, "", false)
	_mutex.lock()
	var key: String = "%s.%s" % [system, event]
	level_counts[level] = level_counts.get(level, 0) + 1
	event_counts[key] = event_counts.get(key, 0) + 1
	if level != "info":
		_remember_problem(key, line)
	if _file:
		_file.store_line(text)
		_file.flush()
	_mutex.unlock()
	# Engine errors are already printed by Godot.
	if level != "info" and system != &"engine":
		print("[%s] %s %s" % [level.to_upper(), key, JSON.stringify(data, "", false)])


func open(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	log_path = path
	session_id = path.get_file().get_basename()
	_started_unix = Time.get_unix_time_from_system()
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		printerr("Log: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])


func summary_path() -> String:
	return log_path.get_basename() + ".summary.json"


## clean_exit stays false until the game quits normally, so a crash leaves a
## summary that says so.
func write_summary(clean_exit: bool) -> void:
	_mutex.lock()
	var summary: Dictionary = {
		"session": session_id,
		"log": ProjectSettings.globalize_path(log_path),
		"version": Build.version,
		"commit": Build.commit,
		"clean_exit": clean_exit,
		"seconds": snappedf(Time.get_unix_time_from_system() - _started_unix, 0.1),
		"max_round": max_round,
		"levels": level_counts.duplicate(),
		"events": event_counts.duplicate(),
		"problems": problems.values(),
		"perf": health.report() if health else {},
	}
	_mutex.unlock()
	var file: FileAccess = FileAccess.open(summary_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(summary, "  ", false))


## Deletes the oldest runs (log + summary) so at most `keep` remain.
static func prune_old_runs(dir: String, keep: int) -> void:
	var logs: Array[String] = _run_logs(dir)
	for i: int in range(0, logs.size() - keep):
		var base: String = "%s/%s" % [dir, logs[i].get_basename()]
		DirAccess.remove_absolute(ProjectSettings.globalize_path(base + ".jsonl"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(base + ".summary.json"))


static func _run_logs(dir: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f: String in DirAccess.get_files_at(dir):
		if f.begins_with("run_") and f.ends_with(".jsonl"):
			out.append(f)
	out.sort()
	return out


func _remember_problem(key: String, line: Dictionary) -> void:
	var data: Dictionary = line["data"]
	var id: String = "%s|%s" % [key, data.get("where", data.get("message", ""))]
	if problems.has(id):
		problems[id]["count"] += 1
		problems[id]["last_frame"] = line["frame"]
	elif problems.size() < MAX_PROBLEMS:
		problems[id] = {"count": 1, "first": line, "last_frame": line["frame"]}


func _previous_log() -> String:
	var logs: Array[String] = _run_logs(DIR)
	logs.erase(log_path.get_file())
	return "" if logs.is_empty() else ProjectSettings.globalize_path("%s/%s" % [DIR, logs[-1]])


func _run_info(role: String) -> Dictionary:
	var out: Dictionary = {
		"role": role,
		"version": Build.version,
		"commit": Build.commit,
		"protocol": Build.PROTOCOL_VERSION,
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"cpu": OS.get_processor_name(),
		"cores": OS.get_processor_count(),
		"args": OS.get_cmdline_user_args(),
		"log": ProjectSettings.globalize_path(log_path),
	}
	if DisplayServer.get_name() != "headless":
		out["gpu"] = RenderingServer.get_video_adapter_name()
		out["driver"] = RenderingServer.get_video_adapter_api_version()
		out["window"] = str(DisplayServer.window_get_size())
	return out


func _connect_events() -> void:
	Events.round_started.connect(_on_round_started)
	Events.round_ended.connect(func(r: int) -> void: info(&"waves", &"round_ended", {"round": r}))
	Events.player_spawned.connect(
		func(p: Player) -> void: info(&"player", &"player_spawned", {"net_id": p.net_id, "at": str(p.global_position)})
	)
	Events.player_died.connect(func(p: Player) -> void: info(&"player", &"player_died", {"net_id": p.net_id}))
	Events.game_over.connect(_on_game_over)
	multiplayer.peer_connected.connect(func(id: int) -> void: info(&"net", &"peer_connected", {"id": id}))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: info(&"net", &"peer_disconnected", {"id": id}))


func _on_round_started(r: int, count: int) -> void:
	round_number = r
	max_round = maxi(max_round, r)
	var data: Dictionary = health.snapshot()
	data["enemies_this_round"] = count
	info(&"waves", &"round_started", data)


func _on_game_over(stats: Dictionary) -> void:
	info(&"game", &"game_over", stats)
	round_number = 0
	write_summary(false)

## Co-op soak: starts one headless dedicated server and N bot clients that play real rounds through the
## join, hit-claim and sync paths. Each process writes a JSON result file; this script checks every log.
## Run: godot --headless --path . --script res://tools/soak/coop_soak.gd -- --clients=2 --rounds=5
extends SceneTree

const SOAK: GDScript = preload("res://tools/soak/soak.gd")
const ROLE_SCRIPTS: Dictionary[String, String] = {
	"server": "res://tools/soak/coop_soak_server.gd",
	"bot": "res://tools/soak/coop_soak_bot.gd",
}
## Two bots hitting the same zombie is normal; the second claim lands on a corpse.
const NORMAL_NET_WARNINGS: Array[String] = ["net.hit_claim_rejected (zombie_not_alive)"]
## Net.MAX_PLAYERS; autoload names do not resolve in a SceneTree script.
const MAX_CLIENTS: int = 8
const DEFAULTS: Dictionary[String, String] = {
	"clients": "2",
	"rounds": "5",
	"seed": "1",
	"timescale": "4",
	"gun": "rifle_ar_reforged",
	"port": "24700",
	"limit": "600",
	"out": "user://coop_soak",
}

var _pids: Array[int] = []
var _started: int = 0


func _initialize() -> void:
	var role: String = arg("role", "run")
	if role in ROLE_SCRIPTS:
		_start_role.call_deferred(role)
	else:
		Engine.max_fps = 10
		_run.call_deferred()


func _start_role(role: String) -> void:
	var script: GDScript = load(ROLE_SCRIPTS[role]) as GDScript
	root.add_child(script.new())


## Value of --name=value after "--", or fallback.
static func arg(name: String, fallback: String = "") -> String:
	var prefix: String = "--%s=" % name
	for item: String in OS.get_cmdline_user_args():
		if item.begins_with(prefix):
			return item.substr(prefix.length())
	return DEFAULTS.get(name, fallback) if fallback.is_empty() else fallback


static func write_result(path: String, data: Dictionary) -> void:
	if path.is_empty():
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


static func read_result(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


func _run() -> void:
	_started = Time.get_ticks_msec()
	var problem: String = _check_args()
	if not problem.is_empty():
		printerr("Co-op soak: ", problem)
		quit(1)
		return
	var out: String = ProjectSettings.globalize_path(arg("out"))
	DirAccess.make_dir_recursive_absolute(out)
	var names: Array[String] = ["server"]
	for index: int in int(arg("clients")):
		names.append("bot%d" % (index + 1))
	for process_name: String in names:
		DirAccess.remove_absolute(out.path_join(process_name + ".json"))
	if not await _launch_server(out):
		printerr("Co-op soak: the server did not start listening")
	else:
		for index: int in range(1, names.size()):
			var extra: Array[String] = ["--join=127.0.0.1:%s" % arg("port"), "--gun=" + arg("gun")]
			extra.append("--leave-delay=%d" % (index - 1))
			_launch(names[index], "bot", out, extra)
			await create_timer(1.0).timeout
		await _wait_for_results(names, out)
	for pid: int in _pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
	var results: Dictionary[String, Dictionary] = {}
	for process_name: String in names:
		results[process_name] = read_result(out.path_join(process_name + ".json"))
	var summary: Dictionary = summarize(results, int(arg("rounds")), int(arg("clients")))
	print_summary(summary, (Time.get_ticks_msec() - _started) / 1000.0)
	quit(1 if summary["failed"] else 0)


func _check_args() -> String:
	for name: String in ["clients", "rounds", "seed", "port", "limit"]:
		if not arg(name).is_valid_int():
			return "--%s must be an integer" % name
	if int(arg("clients")) < 1 or int(arg("clients")) > MAX_CLIENTS:
		return "--clients must be 1 to %d" % MAX_CLIENTS
	if int(arg("rounds")) < 1 or int(arg("limit")) < 1:
		return "--rounds and --limit must be positive"
	if not arg("timescale").is_valid_float() or float(arg("timescale")) <= 0.0:
		return "--timescale must be positive"
	if not ResourceLoader.exists("res://content/weapons/%s.tres" % arg("gun")):
		return "--gun names no weapon in content: " + arg("gun")
	return ""


func _launch_server(out: String) -> bool:
	var ready_file: String = out.path_join("server.ready")
	DirAccess.remove_absolute(ready_file)
	OS.set_environment("EU_READY_FILE", ready_file)
	_launch("server", "server", out, ["--port=" + arg("port")])
	OS.unset_environment("EU_READY_FILE")
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(ready_file):
			return true
		await create_timer(0.5).timeout
	return false


## Each process gets its own XDG_DATA_HOME, so its user:// logs stay apart from the others.
func _launch(process_name: String, role: String, out: String, extra: Array[String]) -> void:
	var data_home: String = out.path_join(process_name)
	DirAccess.make_dir_recursive_absolute(data_home)
	var previous: String = OS.get_environment("XDG_DATA_HOME")
	OS.set_environment("XDG_DATA_HOME", data_home)
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://")]
	args.append_array(["--script", "res://tools/soak/coop_soak.gd", "--", "--role=" + role])
	args.append("--result=" + out.path_join(process_name + ".json"))
	for name: String in ["rounds", "seed", "timescale"]:
		args.append("--%s=%s" % [name, arg(name)])
	args.append_array(PackedStringArray(extra))
	_pids.append(OS.create_process(OS.get_executable_path(), args))
	OS.set_environment("XDG_DATA_HOME", previous)


func _wait_for_results(names: Array[String], out: String) -> void:
	var deadline: int = _started + int(arg("limit")) * 1000
	while Time.get_ticks_msec() < deadline:
		var waiting: bool = false
		for process_name: String in names:
			waiting = waiting or not read_result(out.path_join(process_name + ".json")).get("done", false)
		if not waiting or not OS.is_process_running(_pids[0]):
			break
		await create_timer(1.0).timeout
	await create_timer(2.0).timeout


## Pass/fail for the whole run from each process's result file (empty when it never wrote one).
static func summarize(results: Dictionary[String, Dictionary], rounds: int, clients: int) -> Dictionary:
	var summary: Dictionary = {"failed": false, "rows": [], "reasons": []}
	for process_name: String in results:
		var check: Dictionary = check_process(results[process_name], rounds)
		check["name"] = process_name
		check["result"] = results[process_name]
		summary["rows"].append(check)
		summary["failed"] = summary["failed"] or check["failed"]
	var server: Dictionary = results.get("server", {})
	if int(server.get("players", 0)) < clients:
		summary["failed"] = true
		summary["reasons"].append("server saw %d of %d players" % [int(server.get("players", 0)), clients])
	return summary


## One process: soak.gd's log check (rounds, errors, fail events) plus co-op network warnings.
static func check_process(result: Dictionary, rounds: int) -> Dictionary:
	if result.is_empty():
		return {"failed": true, "reached": 0, "completed": 0, "problems": {}, "reason": "no result file"}
	var check: Dictionary = SOAK.check_log(str(result.get("log", "")), rounds)
	if not result.get("done", false):
		check["failed"] = true
		check["reason"] = "did not finish (%s)" % check.get("reason", "timed out")
	elif result.get("lost_server", false):
		check["failed"] = true
		check["reason"] = "lost the server before the last round ended"
	for key: String in check["problems"].keys():
		if key.begins_with("net.") and not check["problems"][key]["fails"]:
			check["problems"].erase(key)
	_add_net_problems(check, str(result.get("log", "")))
	return check


static func _add_net_problems(check: Dictionary, path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var line_number: int = 0
	while not file.eof_reached():
		var text: String = file.get_line()
		line_number += 1
		var entry: Variant = JSON.parse_string(text) if not text.is_empty() else null
		if not entry is Dictionary or entry.get("system") != "net" or entry.get("level") != "warn":
			continue
		var data: Variant = entry.get("data", {})
		var key: String = "net." + str(entry.get("event", ""))
		if data is Dictionary and data.has("reason"):
			key += " (%s)" % data["reason"]
		var fails: bool = key not in NORMAL_NET_WARNINGS
		check["failed"] = check["failed"] or fails
		if not check["problems"].has(key):
			check["problems"][key] = {"count": 0, "first": text, "line": line_number, "fails": fails}
		check["problems"][key]["count"] += 1


static func print_summary(summary: Dictionary, seconds: float) -> void:
	print("| Process | Result | Rounds reached | Rounds completed | Claims | Moves | Kills | Points |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- |")
	for row: Dictionary in summary["rows"]:
		var result: Dictionary = row["result"]
		var values: Array = [row["name"], "FAIL" if row["failed"] else "PASS", row["reached"], row["completed"]]
		for field: String in ["claims", "moves", "kills", "points"]:
			values.append(str(result.get(field, "—")).trim_suffix(".0"))
		print("| %s | %s | %d | %d | %s | %s | %s | %s |" % values)
	print("")
	print("| Process | Severity / event | Count | First log line |")
	print("| --- | --- | --- | --- |")
	for reason: String in summary["reasons"]:
		print("| run | FAIL: %s | 1 | — |" % reason)
	for row: Dictionary in summary["rows"]:
		if row.has("reason"):
			print("| %s | FAIL: %s | 1 | — |" % [row["name"], row["reason"]])
		for key: String in row["problems"]:
			var problem: Dictionary = row["problems"][key]
			var first: String = str(problem["first"]).replace("|", "&#124;").replace("`", "&#96;")
			var severity: String = "FAIL" if problem["fails"] else "WARN"
			print(
				(
					"| %s | %s: %s | %d | line %d: `%s` |"
					% [row["name"], severity, key, problem["count"], problem["line"], first]
				)
			)
	print("")
	print("| %s | co-op soak, %.1f real s |" % ["FAIL" if summary["failed"] else "PASS", seconds])

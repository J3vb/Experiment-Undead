extends GutTest

const LogScript: GDScript = preload("res://core/log.gd")
const DIR: String = "user://test_logs"

var log_node: Node


func before_each() -> void:
	_clear_dir()
	log_node = LogScript.new()
	log_node.open(DIR + "/run_test_client.jsonl")


func after_each() -> void:
	log_node.free()
	_clear_dir()


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [DIR, f]))


func _read_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for text: String in FileAccess.get_file_as_string(log_node.log_path).split("\n", false):
		var json: JSON = JSON.new()
		assert_eq(json.parse(text), OK, "every line is JSON: %s" % text)
		out.append(json.data)
	return out


func test_lines_are_json_with_context() -> void:
	log_node.round_number = 3
	log_node.info(&"waves", &"round_started", {"enemies": 12})
	log_node.warn(&"enemies", &"zombie_stuck", {"net_id": 7})
	var lines: Array[Dictionary] = _read_lines()
	assert_eq(lines.size(), 2)
	var first: Dictionary = lines[0]
	for key: String in ["time", "up_ms", "frame", "level", "system", "event", "round", "peer", "session", "data"]:
		assert_true(first.has(key), "line has %s" % key)
	assert_eq(first["level"], "info")
	assert_eq(first["event"], "round_started")
	assert_eq(int(first["round"]), 3)
	assert_eq(first["session"], "run_test_client")
	assert_eq(lines[1]["level"], "warn")
	assert_eq(int(lines[1]["data"]["net_id"]), 7)


func test_counts_and_groups_problems() -> void:
	log_node.info(&"waves", &"round_ended")
	for i: int in 3:
		log_node.warn(&"enemies", &"zombie_stuck", {"message": "same"})
	log_node.error(&"level", &"navigation_not_ready")
	assert_eq(log_node.level_counts["warn"], 3)
	assert_eq(log_node.level_counts["error"], 1)
	assert_eq(log_node.event_counts["enemies.zombie_stuck"], 3)
	assert_eq(log_node.problems.size(), 2, "info lines are not problems; repeats are grouped")
	var stuck: Dictionary = log_node.problems["enemies.zombie_stuck|same"]
	assert_eq(stuck["count"], 3)


func test_summary_marks_crash_until_clean_exit() -> void:
	log_node.warn(&"perf", &"low_fps", {"fps": 31.0})
	log_node.write_summary(false)
	var summary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(log_node.summary_path()))
	assert_false(summary["clean_exit"])
	assert_eq(int(summary["events"]["perf.low_fps"]), 1)
	assert_eq(summary["problems"].size(), 1)
	log_node.write_summary(true)
	summary = JSON.parse_string(FileAccess.get_file_as_string(log_node.summary_path()))
	assert_true(summary["clean_exit"])


func test_engine_errors_are_captured_with_place() -> void:
	var capture: EngineErrorCapture = EngineErrorCapture.new(log_node)
	var no_stack: Array[ScriptBacktrace] = []
	capture._log_error("f", "res://x.gd", 12, "code", "Boom", false, Logger.ERROR_TYPE_SCRIPT, no_stack)
	capture._log_error("f", "res://x.gd", 20, "code", "", false, Logger.ERROR_TYPE_WARNING, no_stack)
	var lines: Array[Dictionary] = _read_lines()
	assert_eq(lines[0]["level"], "error")
	assert_eq(lines[0]["event"], "engine_script")
	assert_eq(lines[0]["data"]["message"], "Boom")
	assert_eq(lines[0]["data"]["where"], "res://x.gd:12")
	assert_eq(lines[1]["level"], "warn")
	assert_eq(lines[1]["data"]["message"], "code", "falls back to the code text")


func test_real_push_warning_reaches_the_log() -> void:
	var before: int = Log.event_counts.get("engine.engine_warning", 0)
	push_warning("test_log: captured warning")
	assert_eq(Log.event_counts.get("engine.engine_warning", 0), before + 1)


func test_prunes_oldest_runs() -> void:
	for i: int in 5:
		for ext: String in [".jsonl", ".summary.json"]:
			FileAccess.open("%s/run_2026010%d%s" % [DIR, i, ext], FileAccess.WRITE).store_string("x")
	LogScript.prune_old_runs(DIR, 3)
	var left: PackedStringArray = DirAccess.get_files_at(DIR)
	assert_false(left.has("run_20260100.jsonl"), "oldest run removed")
	assert_false(left.has("run_20260100.summary.json"), "with its summary")
	assert_true(left.has("run_20260104.jsonl"), "newest kept")
	# Kept: runs 03 and 04 (log + summary) and this test's own run_test_client log.
	assert_eq(left.size(), 5)


func test_live_run_has_unique_name_and_early_summary() -> void:
	assert_string_ends_with(Log.session_id, "_%d" % OS.get_process_id(), "pid in the file name")
	assert_true(FileAccess.file_exists(Log.summary_path()), "summary exists from the start")

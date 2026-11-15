## Checks soak pass/fail decisions against fake JSON-lines files, without starting gameplay.
extends GutTest

const SOAK: GDScript = preload("res://tools/soak/soak.gd")
const PATH: String = "user://test_soak.jsonl"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _check(extra: String = "", complete: bool = true) -> Dictionary:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_line('{"system":"waves","event":"round_started","round":10,"level":"info"}')
	if complete:
		file.store_line('{"system":"waves","event":"round_ended","round":10,"level":"info"}')
	file.store_string(extra)
	file.close()
	return SOAK.check_log(PATH, 10)


func test_completed_run_passes() -> void:
	assert_false(_check()["failed"])


func test_any_error_fails_and_keeps_first_line() -> void:
	var line: String = '{"system":"engine","event":"engine_script","level":"error","round":3}\n'
	var result: Dictionary = _check(line + line)
	assert_true(result["failed"])
	assert_eq(result["problems"]["engine.engine_script"]["count"], 2)
	assert_eq(result["problems"]["engine.engine_script"]["first"], line.strip_edges())


func test_stuck_only_warns() -> void:
	var result: Dictionary = _check('{"system":"enemies","event":"zombie_stuck","level":"warn"}\n')
	assert_false(result["failed"])
	assert_eq(result["problems"]["enemies.zombie_stuck"]["count"], 1)
	assert_false(result["problems"]["enemies.zombie_stuck"]["fails"])


func test_fail_events_fail_even_without_error_level() -> void:
	for event: String in SOAK.FAIL_EVENTS:
		var parts: PackedStringArray = event.split(".")
		var line: String = JSON.stringify({"system": parts[0], "event": parts[1], "level": "warn"})
		assert_true(_check(line)["failed"], event)


func test_long_frames_warns() -> void:
	var result: Dictionary = _check('{"system":"perf","event":"long_frames","level":"warn"}')
	assert_false(result["failed"])
	assert_has(result["problems"], "perf.long_frames")


func test_started_but_unfinished_round_fails() -> void:
	assert_true(_check("", false)["failed"])


func test_unreached_round_fails() -> void:
	_check()
	assert_true(SOAK.check_log(PATH, 11)["failed"])


func test_missing_and_malformed_logs_fail() -> void:
	assert_true(SOAK.check_log("user://nonexistent_soak.jsonl", 10)["failed"])
	assert_true(_check("broken json")["failed"])

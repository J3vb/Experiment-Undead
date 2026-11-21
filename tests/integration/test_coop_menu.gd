## Runs the real front end in separate processes, including its six-second deadline.
extends GutTest

const FLOW: String = "res://tests/manual/coop_menu_flow.gd"

var _pid: int = -1
var _result_path: String = ""


func after_each() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	if not _result_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_result_path))


func test_empty_port_returns_to_menu_with_timeout_within_seven_seconds() -> void:
	await _run_flow("timeout")


func test_cancel_returns_without_a_late_timeout_error() -> void:
	await _run_flow("cancel")


func test_enter_world_returns_through_the_existing_match_menu() -> void:
	await _run_flow("host")


func test_a_friend_joins_a_world_started_with_enter_world() -> void:
	var ready_path: String = "user://test_coop_menu_friend_result.json.ready"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ready_path))
	var friend: Array[int] = [-1]
	var join_when_ready: Callable = func() -> void:
		var until: int = Time.get_ticks_msec() + 25000
		while not FileAccess.file_exists(ready_path) and Time.get_ticks_msec() < until:
			await get_tree().process_frame
		var arguments: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://")]
		arguments.append_array(["--", "--join=127.0.0.1:24658"])
		friend[0] = OS.create_process(OS.get_executable_path(), arguments)
	join_when_ready.call()
	await _run_flow("friend", 50.0)
	if friend[0] > 0 and OS.is_process_running(friend[0]):
		OS.kill(friend[0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ready_path))


func _run_flow(mode: String, seconds: float = 25.0) -> void:
	_result_path = "user://test_coop_menu_%s_result.json" % mode
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_result_path))
	var arguments: PackedStringArray = PackedStringArray(
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			FLOW,
			"--",
			"--mode=" + mode,
			"--result=" + _result_path,
			"--warm-hub",
		]
	)
	_pid = OS.create_process(OS.get_executable_path(), arguments)
	assert_gt(_pid, 0, "Started the standalone menu flow")
	if _pid <= 0:
		return
	var finished: Callable = func() -> bool: return not OS.is_process_running(_pid)
	await wait_until(finished, seconds, "The menu process finishes")
	assert_true(FileAccess.file_exists(_result_path), "The menu flow wrote its checks")
	if not FileAccess.file_exists(_result_path):
		return
	var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_result_path))
	assert_eq(result["mode"], mode)
	assert_eq(result["failures"], [], "Menu flow checks: %s" % [result["failures"]])

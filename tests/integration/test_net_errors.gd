## Checks real admission packets and graceful shutdown against separate ENet processes.
extends GutTest

const PORT: int = 24674
const READY: String = "user://net_error_peer.ready"

var _pid: int = -1


func after_each() -> void:
	get_tree().multiplayer_poll = true
	Net.leave()
	Net.last_error.clear()
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	if FileAccess.file_exists(READY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(READY))


func _start_server(scenario: String) -> void:
	var args: PackedStringArray = PackedStringArray(
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			"res://tests/manual/net_error_peer.gd",
			"--",
			"--scenario=" + scenario,
			"--port=%d" % PORT,
			"--ready=" + ProjectSettings.globalize_path(READY),
		]
	)
	_pid = OS.create_process(OS.get_executable_path(), args)
	assert_gt(_pid, 0)
	await wait_until(func() -> bool: return FileAccess.file_exists(READY), 5.0, "server ready")


func _join_and_wait_for_error() -> void:
	assert_eq(Net.join("127.0.0.1:%d" % PORT), OK)
	await wait_until(func() -> bool: return not Net.last_error.is_empty(), 7.0, "a reason reached the client")


func test_server_full_is_rejected_before_player_admission() -> void:
	await _start_server("full")
	await _join_and_wait_for_error()
	assert_eq(Net.last_error.get("reason"), &"server_full")
	assert_eq(Net.last_error.get("details"), {"players": 1, "max_players": 1})
	assert_false(Net.is_online())


func test_wrong_version_reports_both_versions() -> void:
	await _start_server("version")
	await _join_and_wait_for_error()
	assert_eq(Net.last_error.get("reason"), &"wrong_version")
	assert_eq(Net.last_error.get("details"), {"server_version": "0.4.1", "client_version": Build.version})
	assert_false(Net.is_online())


func test_content_mismatch_is_rejected_before_player_admission() -> void:
	await _start_server("content")
	await _join_and_wait_for_error()
	assert_eq(Net.last_error.get("reason"), &"content_mismatch")
	assert_false(Net.is_online())


func test_host_leave_delivers_the_intentional_shutdown_reason() -> void:
	await _start_server("ended")
	await _join_and_wait_for_error()
	assert_eq(Net.last_error.get("reason"), &"host_ended")
	assert_false(Net.is_online())


func test_other_disconnects_report_a_lost_connection() -> void:
	await _start_server("lost")
	await _join_and_wait_for_error()
	assert_eq(Net.last_error.get("reason"), &"lost_connection")


func test_host_process_quit_delivers_shutdown_after_client_polling_stalls() -> void:
	await _start_server("quit")
	Net.join_succeeded.connect(_stall_network_polling, CONNECT_ONE_SHOT)
	await _join_and_wait_for_error()
	assert_eq(Net.last_error.get("reason"), &"host_ended")
	assert_false(Net.is_online())
	await wait_until(func() -> bool: return not OS.is_process_running(_pid), 2.0, "Host finishes after acknowledgement")
	assert_false(OS.is_process_running(_pid), "Acknowledged shutdown does not wait for the whole deadline")


func _stall_network_polling() -> void:
	get_tree().multiplayer_poll = false
	get_tree().create_timer(0.8).timeout.connect(func() -> void: get_tree().multiplayer_poll = true)

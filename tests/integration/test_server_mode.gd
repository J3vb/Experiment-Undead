## End to end: the game build started with "--server" (as the launcher's Host a server does)
## hands over to the dedicated server, answers the server browser and quits on its stop file.
extends GutTest

const PORT: int = 24671
const READY_FILE: String = "user://test_server_mode.ready"
const STOP_FILE: String = "user://test_server_mode.stop"

var _pid: int = -1


func before_all() -> void:
	for path: String in [READY_FILE, STOP_FILE]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func after_all() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	for path: String in [READY_FILE, STOP_FILE]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_game_build_runs_as_server_and_stops_on_its_stop_file() -> void:
	var previous_ready_file: String = OS.get_environment("EU_READY_FILE")
	OS.set_environment("EU_READY_FILE", ProjectSettings.globalize_path(READY_FILE))
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://")]
	args.append_array(ServerHost.server_args(PORT, 3, ProjectSettings.globalize_path(STOP_FILE)).slice(1))
	_pid = OS.create_process(OS.get_executable_path(), args)
	if previous_ready_file.is_empty():
		OS.unset_environment("EU_READY_FILE")
	else:
		OS.set_environment("EU_READY_FILE", previous_ready_file)
	assert_gt(_pid, 0)
	await wait_until(func() -> bool: return FileAccess.file_exists(READY_FILE), 30.0, "server listening")
	assert_true(FileAccess.file_exists(READY_FILE), "--server opened the port instead of showing the menu")
	var info: Dictionary = await _query()
	assert_eq(info.get("max"), 3, "max players from the command line")
	FileAccess.open(STOP_FILE, FileAccess.WRITE).store_string("stop")
	await wait_until(func() -> bool: return not OS.is_process_running(_pid), 15.0, "server stopped")
	assert_false(OS.is_process_running(_pid), "stop file from the command line ends the server")


func _query() -> Dictionary:
	var nonce: PackedByteArray = PackedByteArray([9, 9, 9, 9, 1, 2, 3, 4])
	var socket: PacketPeerUDP = PacketPeerUDP.new()
	socket.bind(0, "127.0.0.1")
	var info: Dictionary = {}
	for i: int in 90:
		if i % 10 == 0:
			ServerInfo.send_queries(socket, nonce, PackedInt32Array([PORT + ServerInfo.PORT_OFFSET]), "127.0.0.1")
		await wait_physics_frames(1)
		while info.is_empty() and socket.get_available_packet_count() > 0:
			info = ServerInfo.parse_reply(socket.get_packet(), nonce)
		if not info.is_empty():
			break
	socket.close()
	return info

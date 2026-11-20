extends GutTest

var saved_config: String = ""


func before_each() -> void:
	saved_config = FileAccess.get_file_as_string(ServerHost.CONFIG)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ServerHost.CONFIG))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ServerHost.CONFIG))
	if not saved_config.is_empty():
		FileAccess.open(ServerHost.CONFIG, FileAccess.WRITE).store_string(saved_config)


func test_server_args() -> void:
	var args: PackedStringArray = ServerHost.server_args(7790, 4, "/tmp/eu.stop")
	assert_eq(
		args,
		PackedStringArray(
			["--headless", "--", "--server", "--port=7790", "--max-players=4", "--stop-file=/tmp/eu.stop"]
		)
	)


func test_server_args_clamp() -> void:
	var args: PackedStringArray = ServerHost.server_args(0, 99, "f")
	assert_has(args, "--port=1")
	assert_has(args, "--max-players=%d" % Net.MAX_PLAYERS)


func test_settings_are_saved_and_loaded() -> void:
	var host: ServerHost = ServerHost.new()
	add_child_autofree(host)
	assert_eq(host.port, Net.DEFAULT_PORT)
	assert_eq(host.max_players, Net.MAX_PLAYERS)
	host.save(7790, 20)
	var again: ServerHost = ServerHost.new()
	add_child_autofree(again)
	assert_eq(again.port, 7790)
	assert_eq(again.max_players, Net.MAX_PLAYERS, "clamped")
	assert_false(again.is_running())


func test_server_mode_has_its_own_crash_marker() -> void:
	assert_ne(Build.SERVER_CRASH_MARKER, Build.CRASH_MARKER)
	assert_eq(Build.crash_marker(), Build.CRASH_MARKER, "tests run as a client")

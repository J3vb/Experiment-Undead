extends GutTest

const MARKER: String = "user://test_running.lock"
const VERSION_PATH: String = "user://test_version.json"
const BuildScript: GDScript = preload("res://core/build.gd")


func after_each() -> void:
	for p: String in [MARKER, VERSION_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_crash_marker() -> void:
	assert_false(Build.begin_run(MARKER), "first run is clean")
	assert_true(Build.begin_run(MARKER), "marker left behind = crash")
	Build.end_run(MARKER)
	assert_false(FileAccess.file_exists(MARKER))
	assert_false(Build.begin_run(MARKER), "clean quit clears it")


func test_reads_version_file() -> void:
	var f: FileAccess = FileAccess.open(VERSION_PATH, FileAccess.WRITE)
	f.store_string('{"version": "0.1.0", "commit": "abc1234", "built_at": "2026-11-14T00:00:00Z"}')
	f.close()
	var b: Node = BuildScript.new()
	b.load_version_file(VERSION_PATH)
	assert_eq(b.version, "0.1.0")
	assert_eq(b.commit, "abc1234")
	assert_eq(b.display_version(), "v0.1.0")
	b.free()


func test_editor_version_without_file() -> void:
	var b: Node = BuildScript.new()
	b.load_version_file("user://does_not_exist.json")
	assert_eq(b.display_version(), "dev (editor)")
	b.free()


func test_protocol_check() -> void:
	assert_true(Build.is_protocol_compatible(Build.PROTOCOL_VERSION))
	assert_false(Build.is_protocol_compatible(Build.PROTOCOL_VERSION + 1))


func test_server_port_falls_back() -> void:
	assert_eq(DedicatedServer.read_int_setting("no-such-arg", "EU_NO_SUCH_ENV", 7777), 7777)

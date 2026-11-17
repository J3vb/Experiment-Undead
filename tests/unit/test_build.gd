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


func test_content_hash_sorts_ids_without_changing_the_source() -> void:
	var ids: PackedStringArray = ["weapons/rifle_ar", "enemies/zombie_walker", "loot/dmg_pct"]
	var reordered: PackedStringArray = ["loot/dmg_pct", "weapons/rifle_ar", "enemies/zombie_walker"]
	assert_eq(Build.hash_content_ids(ids), Build.hash_content_ids(reordered))
	assert_eq(ids[0], "weapons/rifle_ar")
	reordered.append("loot/new_affix")
	assert_ne(Build.hash_content_ids(ids), Build.hash_content_ids(reordered))


func test_startup_hash_contains_every_content_category() -> void:
	var ids: PackedStringArray = []
	var root: DirAccess = DirAccess.open(Content.ROOT)
	for category: String in root.get_directories():
		for id: StringName in Content.ids(StringName(category)):
			ids.append(category + "/" + String(id))
	assert_gt(Content.ids(&"loot").size(), 0, "loot ids take part in compatibility")
	assert_eq(Build.content_hash, Build.hash_content_ids(ids))
	assert_eq(Build.content_hash.length(), 64, "compatibility uses SHA-256")


func test_server_port_falls_back() -> void:
	assert_eq(DedicatedServer.read_int_setting("no-such-arg", "EU_NO_SUCH_ENV", 7777), 7777)


func test_only_plain_release_versions_are_stable() -> void:
	for version: String in ["0.1.0", "1.20.3"]:
		assert_true(Build.is_stable_version(version), version)
	for version: String in ["dev", "0.1.0-test.1", "0.1.0-dev.4+abc123", "0.1", "v0.1.0", ""]:
		assert_false(Build.is_stable_version(version), version)

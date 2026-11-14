extends GutTest

const PATH: String = "user://test_save.json"


func after_each() -> void:
	for p: String in [PATH, PATH + ".tmp", PATH + ".v0.bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write_raw(text: String) -> void:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_one_migration_step_per_version() -> void:
	assert_eq(SaveFile._migrations().size(), SaveFile.CURRENT_VERSION)


func test_round_trip_stamps_version() -> void:
	assert_eq(SaveFile.write(PATH, {"xp": 120}), OK)
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq(int(data["xp"]), 120)
	assert_eq(int(data[SaveFile.VERSION_KEY]), SaveFile.CURRENT_VERSION)
	assert_false(FileAccess.file_exists(PATH + ".tmp"))


func test_unversioned_save_is_upgraded_and_backed_up() -> void:
	_write_raw('{"xp": 5}')
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq(int(data["xp"]), 5)
	assert_eq(int(data[SaveFile.VERSION_KEY]), SaveFile.CURRENT_VERSION)
	assert_true(FileAccess.file_exists(PATH + ".v0.bak"))


func test_newer_save_is_refused() -> void:
	_write_raw('{"save_version": %d, "xp": 5}' % (SaveFile.CURRENT_VERSION + 1))
	assert_eq(SaveFile.read(PATH), {})
	assert_push_error("Update the game")


func test_broken_save_is_refused() -> void:
	_write_raw("{not json")
	assert_eq(SaveFile.read(PATH), {})
	assert_push_error("not valid JSON")


func test_missing_save_is_empty() -> void:
	assert_eq(SaveFile.read(PATH), {})


func test_steps_run_in_order() -> void:
	var steps: Array[Callable] = [_step_add_a, _step_add_b]
	var out: Dictionary = SaveFile.upgrade({}, steps)
	assert_eq(out, {"a": 1, "b": 2, SaveFile.VERSION_KEY: 2})
	var from_one: Dictionary = SaveFile.upgrade({"a": 10, SaveFile.VERSION_KEY: 1}, steps)
	assert_eq(int(from_one["b"]), 11)


func _step_add_a(d: Dictionary) -> Dictionary:
	d["a"] = 1
	return d


func _step_add_b(d: Dictionary) -> Dictionary:
	d["b"] = int(d["a"]) + 1
	return d

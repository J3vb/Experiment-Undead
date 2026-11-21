extends GutTest

const PATH: String = "user://test_save.json"


func after_each() -> void:
	for p: String in [PATH, PATH + ".tmp", PATH + ".v0.bak", PATH + ".v1.bak", PATH + ".v2.bak", PATH + ".v3.bak"]:
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


func test_version_2_save_upgrades_to_3_unchanged_and_is_backed_up() -> void:
	var old: Dictionary = {"save_version": 2, "loadout": {"vest": {"uid": "v"}}, "best_runs": {}}
	var step: Dictionary = SaveFile.upgrade(old, SaveFile._migrations().slice(0, 3))
	assert_eq(int(step[SaveFile.VERSION_KEY]), 3)
	assert_eq(step["loadout"], {"vest": {"uid": "v"}})
	_write_raw(JSON.stringify(old))
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq(int(data[SaveFile.VERSION_KEY]), SaveFile.CURRENT_VERSION)
	assert_eq(data["loadout"], {"vest": {"uid": "v"}})
	assert_true(FileAccess.file_exists(PATH + ".v2.bak"))


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


func test_version_1_save_gains_empty_best_runs_and_keeps_its_fields() -> void:
	_write_raw('{"save_version": 1, "id": "old", "total_xp": 400, "loadout": {}}')
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq(int(data[SaveFile.VERSION_KEY]), SaveFile.CURRENT_VERSION)
	assert_eq(data["best_runs"], {})
	assert_eq(int(data["total_xp"]), 400)
	assert_true(FileAccess.file_exists(PATH + ".v1.bak"))


func test_saved_version_tells_newer_from_broken() -> void:
	assert_eq(SaveFile.saved_version(PATH), -1, "missing")
	_write_raw("{broken")
	assert_eq(SaveFile.saved_version(PATH), -1, "broken")
	_write_raw('{"total_xp": 5}')
	assert_eq(SaveFile.saved_version(PATH), 0, "unversioned")
	_write_raw('{"save_version": "x"}')
	assert_eq(SaveFile.saved_version(PATH), -1, "version is not a number")
	var newer: String = '{"save_version": %d}' % (SaveFile.CURRENT_VERSION + 1)
	_write_raw(newer)
	assert_eq(SaveFile.saved_version(PATH), SaveFile.CURRENT_VERSION + 1)
	assert_eq(FileAccess.get_file_as_string(PATH), newer, "reading the version changes nothing")


func test_version_3_save_gains_an_empty_field_ability_pick() -> void:
	_write_raw('{"save_version": 3, "id": "old", "total_xp": 400, "loadout": {"vest": {"uid": "v"}}}')
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq(int(data[SaveFile.VERSION_KEY]), 4)
	assert_eq(data["field_ability"], "")
	assert_eq(data["loadout"], {"vest": {"uid": "v"}}, "other fields stay")
	assert_true(FileAccess.file_exists(PATH + ".v3.bak"))

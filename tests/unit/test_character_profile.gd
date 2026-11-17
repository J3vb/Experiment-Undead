## Character serialization, forward fields, safe loading and derived levels.
extends GutTest

const ID: StringName = &"test_character_profile"
const PATH: String = "user://characters/test_character_profile.json"
const RULES: XpRules = preload("res://content/progression/xp_rules.tres")


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CharacterProfile.DIRECTORY))
	_remove_files()


func after_each() -> void:
	_remove_files()


func _remove_files() -> void:
	for path: String in [PATH, PATH + ".tmp", PATH + ".v0.bak", PATH + ".v1.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_dictionary_round_trip() -> void:
	var data: Dictionary = {
		"id": String(ID),
		"display_name": "Survivor",
		"total_xp": 1234,
		"skill_ranks": {},
	}
	var profile: CharacterProfile = CharacterProfile.from_dict(data)
	assert_eq(profile.id, ID)
	assert_eq(profile.display_name, "Survivor")
	assert_eq(profile.total_xp, 1234)
	assert_eq(profile.skill_ranks, {})
	var saved: Dictionary = profile.to_dict()
	saved.erase("stash")
	saved.erase("loadout")
	saved.erase("best_runs")
	assert_eq(saved, data)


func test_new_profile_has_60_empty_stash_slots_and_five_loadout_slots() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	assert_eq(profile.stash.size(), 60)
	for item: Dictionary in profile.stash:
		assert_eq(item, {})
	assert_eq(profile.loadout, {"primary": {}, "sidearm": {}, "vest": {}, "charm": {}, "implant": {}})
	profile.stash[0]["uid"] = "first"
	profile.loadout["primary"]["uid"] = "equipped"
	assert_eq(profile.stash[1], {})
	assert_eq(profile.loadout["sidearm"], {})
	var other: CharacterProfile = CharacterProfile.new()
	assert_eq(other.stash[0], {})
	assert_eq(other.loadout["primary"], {})


func test_inventory_dictionary_round_trip_keeps_slot_positions() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	profile.stash[3] = {"uid": "stashed", "base": "rifle_ar", "aff": [["dmg_pct", 2, 0.25]]}
	profile.stash[59] = {"uid": "last", "base": "hollis_44"}
	profile.loadout["sidearm"] = {"uid": "equipped", "base": "hollis_44"}
	var loaded: CharacterProfile = CharacterProfile.from_dict(profile.to_dict())
	assert_eq(loaded.stash, profile.stash)
	assert_eq(loaded.stash.size(), 60)
	assert_eq(loaded.stash[0], {})
	assert_eq(loaded.stash[3]["uid"], "stashed")
	assert_eq(loaded.stash[59]["uid"], "last")
	assert_eq(loaded.loadout, profile.loadout)


func test_short_stash_with_nulls_loads_as_60_dictionary_slots() -> void:
	var profile: CharacterProfile = CharacterProfile.from_dict({"stash": [null, {"uid": "kept"}, null]})
	assert_eq(profile.stash.size(), 60)
	assert_eq(profile.stash[0], {})
	assert_eq(profile.stash[1], {"uid": "kept"})
	assert_eq(profile.stash[2], {})
	assert_eq(profile.stash[59], {})


func test_old_v1_save_defaults_to_empty_inventory_without_migration() -> void:
	_write_raw('{"save_version": 1, "id": "test_character_profile", "total_xp": 400}')
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(profile.total_xp, 400)
	assert_eq(profile.stash.size(), 60)
	for item: Dictionary in profile.stash:
		assert_eq(item, {})
	assert_eq(profile.loadout, {"primary": {}, "sidearm": {}, "vest": {}, "charm": {}, "implant": {}})
	assert_eq(profile.best_runs, {})
	assert_eq(profile.save(), OK)
	assert_eq(int(SaveFile.read(PATH)["save_version"]), SaveFile.CURRENT_VERSION)


func test_legacy_empty_array_loadout_deserializes_without_changing_input() -> void:
	var data: Dictionary = {"id": String(ID), "total_xp": 400, "loadout": []}
	var profile: CharacterProfile = CharacterProfile.from_dict(data)
	assert_eq(profile.total_xp, 400)
	assert_eq(profile.loadout, {"primary": {}, "sidearm": {}, "vest": {}, "charm": {}, "implant": {}})
	assert_eq(data["loadout"], [])


func test_legacy_empty_array_save_keeps_xp_items_unknown_fields_and_can_save() -> void:
	var data: Dictionary = {
		"id": String(ID),
		"display_name": "Rook",
		"total_xp": RULES.total_xp_for_level(14),
		"loadout": [],
		"stash": [{"uid": "kept", "future": {"retired": true}}],
		"future_flag": true,
	}
	assert_eq(SaveFile.write(PATH, data), OK)
	var before: Dictionary = SaveFile.read(PATH)
	var warnings: int = Log.event_counts.get("progression.profile_unreadable", 0)
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(profile.total_xp, int(data["total_xp"]))
	assert_eq(profile.level, 14)
	assert_eq(profile.display_name, "Rook")
	assert_eq(profile.stash[0], before["stash"][0])
	assert_eq(Log.event_counts.get("progression.profile_unreadable", 0), warnings)
	profile.total_xp += 75
	assert_eq(profile.save(), OK)
	var saved: Dictionary = SaveFile.read(PATH)
	assert_eq(int(saved["total_xp"]), int(data["total_xp"]) + 75)
	assert_true(saved["future_flag"])
	assert_eq(saved["stash"][0], before["stash"][0])
	assert_eq(saved["loadout"], {"primary": {}, "sidearm": {}, "vest": {}, "charm": {}, "implant": {}})
	assert_eq(int(saved["save_version"]), SaveFile.CURRENT_VERSION)


func test_legacy_v1_empty_loadout_array_keeps_xp_and_remains_saveable() -> void:
	_write_raw('{"save_version": 1, "id": "test_character_profile", "total_xp": 400, "loadout": []}')
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(profile.total_xp, 400)
	assert_eq(profile.stash.size(), 60)
	for item: Dictionary in profile.stash:
		assert_eq(item, {})
	var empty_loadout: Dictionary = {"primary": {}, "sidearm": {}, "vest": {}, "charm": {}, "implant": {}}
	assert_eq(profile.loadout, empty_loadout)
	var parsed: CharacterProfile = CharacterProfile.from_dict({"loadout": []})
	assert_eq(parsed.loadout, empty_loadout)
	assert_eq(profile.save(), OK)
	var saved: Dictionary = SaveFile.read(PATH)
	assert_true(saved["loadout"] is Dictionary)
	assert_eq(saved["loadout"], empty_loadout)
	assert_eq(int(saved["total_xp"]), 400)
	assert_eq(int(saved["save_version"]), SaveFile.CURRENT_VERSION)


func test_unknown_fields_survive_load_and_save() -> void:
	var data: Dictionary = {
		"id": String(ID),
		"total_xp": 400,
		"stash": [{"uid": "item", "aff": [["removed_affix", 3, 0.5]], "future": [1, null, {"a": true}]}],
		"loadout": {"primary": {"uid": "equipped", "future": {"nested": [false, null, "kept"]}}},
		"future_flag": false,
	}
	assert_eq(SaveFile.write(PATH, data), OK)
	var original: Dictionary = SaveFile.read(PATH)
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	profile.total_xp += 75
	assert_eq(profile.save(), OK)
	var saved: Dictionary = SaveFile.read(PATH)
	assert_eq(saved["stash"][0], original["stash"][0])
	assert_eq(saved["stash"].size(), 60)
	assert_eq(saved["loadout"]["primary"], original["loadout"]["primary"])
	assert_eq(saved["future_flag"], false)
	assert_eq(int(saved["total_xp"]), 475)
	var loaded: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(loaded.stash[0], saved["stash"][0])
	assert_eq(loaded.loadout["primary"], saved["loadout"]["primary"])


func test_inventory_dictionary_copies_do_not_share_nested_item_data() -> void:
	var data: Dictionary = {
		"stash": [{"uid": "stashed", "future": {"locked": true}}],
		"loadout": {"primary": {"uid": "equipped", "future": {"locked": true}}},
	}
	var profile: CharacterProfile = CharacterProfile.from_dict(data)
	data["stash"][0]["future"]["locked"] = false
	data["loadout"]["primary"]["future"]["locked"] = false
	assert_true(profile.stash[0]["future"]["locked"])
	assert_true(profile.loadout["primary"]["future"]["locked"])
	var saved: Dictionary = profile.to_dict()
	saved["stash"][0]["future"]["locked"] = false
	saved["loadout"]["primary"]["future"]["locked"] = false
	assert_true(profile.stash[0]["future"]["locked"])
	assert_true(profile.loadout["primary"]["future"]["locked"])


func test_missing_file_gives_new_saveable_profile() -> void:
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(profile.id, ID)
	assert_eq(profile.display_name, "Survivor")
	assert_eq(profile.total_xp, 0)
	assert_eq(profile.skill_ranks, {})
	assert_false(FileAccess.file_exists(PATH))
	assert_eq(profile.save(), OK)
	assert_true(FileAccess.file_exists(PATH))


func test_newer_file_is_not_overwritten() -> void:
	var raw: String = '{"save_version": %d, "total_xp": 9000}' % (SaveFile.CURRENT_VERSION + 1)
	_write_raw(raw)
	var warnings: int = Log.event_counts.get("progression.profile_unreadable", 0)
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_push_error("Update the game")
	assert_eq(profile.total_xp, 0)
	profile.total_xp += 60
	assert_eq(profile.save(), ERR_UNAVAILABLE)
	assert_eq(profile.save(), ERR_UNAVAILABLE)
	assert_eq(FileAccess.get_file_as_string(PATH), raw)
	assert_eq(Log.event_counts.get("progression.profile_unreadable", 0), warnings + 1)
	assert_false(FileAccess.file_exists(PATH + ".tmp"))


func test_broken_file_is_not_overwritten() -> void:
	_write_raw("{broken")
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_push_error("not valid JSON")
	assert_eq(profile.total_xp, 0)
	assert_eq(profile.save(), ERR_UNAVAILABLE)
	assert_eq(FileAccess.get_file_as_string(PATH), "{broken")


func test_malformed_fields_use_temporary_profile() -> void:
	for fields: Dictionary in [
		{"total_xp": "bad"},
		{"total_xp": -1},
		{"total_xp": 2.5},
		{"display_name": []},
		{"skill_ranks": []},
		{"id": []},
		{"stash": {}},
		{"stash": ["bad"]},
		{"loadout": [{}]},
		{"loadout": {"primary": "bad"}},
	]:
		assert_eq(SaveFile.write(PATH, fields), OK)
		var raw: String = FileAccess.get_file_as_string(PATH)
		var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
		assert_eq(profile.total_xp, 0)
		assert_eq(profile.save(), ERR_UNAVAILABLE)
		assert_eq(FileAccess.get_file_as_string(PATH), raw)


func test_level_is_derived_and_never_stored() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	assert_eq(profile.level, 1)
	profile.total_xp = RULES.total_xp_for_level(10)
	assert_eq(profile.level, 10)
	assert_false(profile.to_dict().has("level"))
	profile = CharacterProfile.from_dict(profile.to_dict())
	assert_eq(profile.level, RULES.level_for_total_xp(profile.total_xp))
	profile.total_xp = 0
	assert_eq(profile.level, 1)


func test_failed_save_is_logged() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	profile.id = &"test_missing_character_folder/profile"
	var warnings: int = Log.event_counts.get("progression.profile_save_failed", 0)
	assert_ne(profile.save(), OK)
	assert_eq(Log.event_counts.get("progression.profile_save_failed", 0), warnings + 1)


func _write_raw(raw: String) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(raw)
	file.close()


func test_best_run_per_map_keeps_highest_round_then_kills_and_saves() -> void:
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_true(profile.record_run("halcyon_labs", {"round": 7, "kills": 80}), "first run is a best")
	assert_false(profile.record_run("halcyon_labs", {"round": 6, "kills": 200}), "lower round")
	assert_false(profile.record_run("halcyon_labs", {"round": 7, "kills": 80}), "a tie is not new")
	assert_true(profile.record_run("halcyon_labs", {"round": 7, "kills": 81}), "more kills breaks a tie")
	assert_true(profile.record_run("other_map", {"round": 2, "kills": 5}), "maps are separate")
	var loaded: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(int(loaded.best_runs["halcyon_labs"]["round"]), 7)
	assert_eq(int(loaded.best_runs["halcyon_labs"]["kills"]), 81)
	assert_eq(int(loaded.best_runs["other_map"]["round"]), 2)


func test_round_zero_run_is_not_a_best() -> void:
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_false(profile.record_run("halcyon_labs", {"round": 0, "kills": 0}))
	assert_false(FileAccess.file_exists(PATH), "nothing to save")

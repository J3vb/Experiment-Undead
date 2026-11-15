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
	for path: String in [PATH, PATH + ".tmp", PATH + ".v0.bak"]:
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
	assert_eq(profile.to_dict(), data)


func test_unknown_fields_survive_load_and_save() -> void:
	var data: Dictionary = {
		"id": String(ID),
		"total_xp": 400,
		"stash": [{"uid": "item", "future": [1, null, {"a": true}]}],
		"loadout": [],
		"future_flag": false,
	}
	assert_eq(SaveFile.write(PATH, data), OK)
	var original: Dictionary = SaveFile.read(PATH)
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	profile.total_xp += 75
	assert_eq(profile.save(), OK)
	var saved: Dictionary = SaveFile.read(PATH)
	assert_eq(saved["stash"], original["stash"])
	assert_eq(saved["loadout"], [])
	assert_eq(saved["future_flag"], false)
	assert_eq(int(saved["total_xp"]), 475)


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

## The nine loadout slots: save order, version 2 saves, and the F-71 gear slots on disk.
extends GutTest

const ID: StringName = &"test_character_slots"

var _path: String = CharacterProfile.directory() + "test_character_slots.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CharacterProfile.directory()))
	_remove_files()


func after_each() -> void:
	_remove_files()


func _remove_files() -> void:
	for path: String in [_path, _path + ".tmp", _path + ".v2.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_raw(text: String) -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_version_2_save_loads_four_empty_new_slots_and_saves_as_the_current_version() -> void:
	var vest: String = '{"uid": "old_vest", "base": "vest_medium"}'
	_write_raw('{"save_version": 2, "id": "test_character_slots", "loadout": {"vest": %s}}' % vest)
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(profile.loadout["vest"]["uid"], "old_vest")
	for slot: String in ["headgear", "gloves", "backpack", "boots"]:
		assert_eq(profile.loadout[slot], {}, slot)
	assert_eq(profile.save(), OK)
	var saved: Dictionary = SaveFile.read(_path)
	assert_eq(int(saved["save_version"]), SaveFile.CURRENT_VERSION)
	assert_eq(saved["loadout"].keys().size(), 9)


func test_headgear_item_survives_a_save_round_trip() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	profile.id = ID
	profile.loadout["headgear"] = {"uid": "cap", "base": "headgear_cap", "rar": "rare", "aff": []}
	assert_eq(profile.save(), OK)
	var loaded: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(loaded.loadout["headgear"]["uid"], "cap")
	assert_eq(loaded.loadout["headgear"]["base"], "headgear_cap")


func test_slots_are_nine_in_save_order_and_gear_is_the_last_seven() -> void:
	assert_eq(CharacterProfile.SLOTS.size(), 9)
	assert_eq(CharacterProfile.GEAR_SLOTS, CharacterProfile.SLOTS.slice(2))
	var keys: Array = []
	for slot: StringName in CharacterProfile.SLOTS:
		keys.append(String(slot))
	assert_eq(CharacterProfile.new().loadout.keys(), keys)

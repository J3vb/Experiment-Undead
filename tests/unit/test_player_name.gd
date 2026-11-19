## Player names: what clean_name keeps, cuts and replaces, loaded saves, and typing on the Character screen.
extends GutTest

const SCREEN: PackedScene = preload("res://systems/ui/character_screen.tscn")
const PROFILE_ID: StringName = &"test_player_name"

var _profile_path: String = CharacterProfile.directory() + "test_player_name.json"


func after_each() -> void:
	for path: String in [_profile_path, _profile_path + ".tmp", _profile_path + ".v0.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _open_screen() -> CharacterScreen:
	var profile: CharacterProfile = CharacterProfile.new()
	profile.id = PROFILE_ID
	profile.display_name = "Rook"
	profile.stash[0] = {"v": 1, "uid": "old", "base": "rifle_ar", "rar": "common", "ilvl": 8, "aff": [], "imp": []}
	var screen: CharacterScreen = SCREEN.instantiate() as CharacterScreen
	add_child_autofree(screen)
	screen.open(profile)
	return screen


func test_plain_and_accented_names_stay_as_typed() -> void:
	assert_eq(CharacterProfile.clean_name("Rook"), "Rook")
	assert_eq(CharacterProfile.clean_name("Zoë-Ange_2"), "Zoë-Ange_2")
	assert_eq(CharacterProfile.clean_name("O'Neil Jr."), "O'Neil Jr.")


func test_symbols_tabs_and_newlines_are_dropped_and_spaces_squeezed() -> void:
	assert_eq(CharacterProfile.clean_name("  Night<>\t\n  Owl  "), "Night Owl")
	assert_eq(CharacterProfile.clean_name("[color=red]Red[/color]"), "colorredRedcolor")
	assert_eq(CharacterProfile.clean_name("名前Fox"), "Fox")


func test_long_names_are_cut_to_the_limit_without_a_trailing_space() -> void:
	var cleaned: String = CharacterProfile.clean_name("Night Owl of the Ridge")
	assert_eq(cleaned, "Night Owl of the")
	assert_eq(cleaned.length(), CharacterProfile.NAME_MAX)
	assert_eq(CharacterProfile.clean_name("Fifteen letters a"), "Fifteen letters")


func test_empty_or_nothing_left_gives_the_default_name() -> void:
	for typed: String in ["", "   ", "<<>>", "名前"]:
		assert_eq(CharacterProfile.clean_name(typed), CharacterProfile.DEFAULT_NAME, typed)


func test_loading_a_hand_edited_save_cleans_its_name() -> void:
	var profile: CharacterProfile = CharacterProfile.from_dict({"display_name": "  <Ghost>  of\tthe ridge road"})
	assert_eq(profile.display_name, "Ghost ofthe ridg")


func test_typed_name_is_cleaned_and_saved_on_close() -> void:
	var screen: CharacterScreen = _open_screen()
	var field: NameField = screen.get_node("%Name") as NameField
	field.grab_focus()
	field.text = " Ash  <>\tTree "
	field.release_focus()
	assert_eq(field.text, "Ash Tree")
	field.grab_focus()
	field.text = "Wren"
	screen._close()
	assert_eq(CharacterProfile.load_or_create(PROFILE_ID).display_name, "Wren", "Back saves a name still being typed")


func test_keys_typed_in_the_name_do_not_equip_or_close() -> void:
	var screen: CharacterScreen = _open_screen()
	var profile: CharacterProfile = screen.profile
	var before: Dictionary = profile.to_dict()
	(screen.get_node("%Name") as NameField).grab_focus()
	watch_signals(screen)
	screen._input(_key(KEY_E))
	screen._input(_key(KEY_ESCAPE))
	assert_eq(profile.to_dict(), before)
	assert_signal_not_emitted(screen, "closed")


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event

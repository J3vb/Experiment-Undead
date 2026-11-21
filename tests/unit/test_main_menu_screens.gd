## Main menu screens opened through the UI router: settings, character and research, Back and focus.
extends GutTest

const MENU: PackedScene = preload("res://systems/ui/main_menu.tscn")
const SETTINGS_PATH: String = "user://test_main_menu_screens_settings.cfg"

var menu: MainMenu
var _settings_path: String
var _settings_values: Dictionary


func before_each() -> void:
	_settings_path = Settings.config_path
	_settings_values = Settings._values.duplicate(true)
	Settings.config_path = SETTINGS_PATH
	Settings.reset_to_defaults()
	menu = MENU.instantiate() as MainMenu
	add_child_autofree(menu)


func after_each() -> void:
	while UI.top() != &"":
		UI.pop()
	Settings._values = _settings_values
	Settings.config_path = _settings_path
	Settings._apply_all()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _top_screen() -> Node:
	return UI._stack.back()["layer"].get_child(0) if not UI._stack.is_empty() else null


func test_settings_opens_through_the_router_with_fade_and_back_restores_focus() -> void:
	assert_null(menu.get_node_or_null("Screens/Root/SettingsScreen"), "the menu adds no screen nodes itself")
	menu.settings_button.grab_focus()
	menu.settings_button.pressed.emit()
	assert_eq(UI.top(), &"settings")
	var screen: SettingsScreen = _top_screen() as SettingsScreen
	assert_eq(screen.scene_file_path, "res://systems/ui/settings_screen.tscn")
	assert_eq((screen.get_parent() as CanvasLayer).layer, 20)
	assert_true(screen.is_visible_in_tree())
	screen.fade.pause()
	assert_eq(screen.position.x, 12.0)
	assert_eq(screen.modulate.a, 0.0)
	screen.fade.custom_step(0.12)
	assert_almost_eq(screen.position.x, 0.0, 0.01)
	assert_almost_eq(screen.modulate.a, 1.0, 0.01)
	(screen.get_node("%Back") as Button).pressed.emit()
	assert_eq(UI.top(), &"")
	assert_true(menu.settings_button.has_focus())


func test_loadout_opens_solo_profile_and_close_restores_menu_focus() -> void:
	menu.loadout_button.grab_focus()
	menu.loadout_button.pressed.emit()
	assert_eq(UI.top(), &"character")
	var screen: CharacterScreen = _top_screen() as CharacterScreen
	assert_eq(screen.profile.id, &"solo")
	assert_true(screen.is_visible_in_tree())
	assert_true(screen.is_ancestor_of(get_viewport().gui_get_focus_owner()))
	screen.closed.emit()
	assert_eq(UI.top(), &"")
	assert_true(menu.loadout_button.has_focus())
	assert_true(screen.get_parent().is_queued_for_deletion())


func test_loadout_owns_cancel_and_only_one_screen_opens() -> void:
	menu.loadout_button.grab_focus()
	menu.loadout_button.pressed.emit()
	var screen: CharacterScreen = _top_screen() as CharacterScreen
	menu.loadout_button.pressed.emit()
	assert_eq(UI._stack.size(), 1, "a second press opens nothing")
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	menu._input(cancel)
	assert_eq(_top_screen(), screen, "Character screen receives its own back input")


func test_loadout_failed_save_needs_a_second_back() -> void:
	menu.loadout_button.grab_focus()
	menu.loadout_button.pressed.emit()
	var screen: CharacterScreen = _top_screen() as CharacterScreen
	screen.profile.id = &"test_main_menu_missing/profile"
	screen._close()
	assert_eq(UI.top(), &"character", "a failed save keeps the screen open")
	screen._close()
	assert_eq(UI.top(), &"")
	assert_true(menu.loadout_button.has_focus())


func test_pushed_screen_draws_above_the_menu_and_takes_the_mouse() -> void:
	menu.settings_button.grab_focus()
	menu.settings_button.pressed.emit()
	var screen: SettingsScreen = _top_screen() as SettingsScreen
	assert_gt((screen.get_parent() as CanvasLayer).layer, (menu.get_node("Screens") as CanvasLayer).layer)
	await wait_process_frames(2)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = menu.enter_button.get_global_rect().get_center()
	motion.global_position = motion.position
	get_viewport().push_input(motion)
	await wait_process_frames(1)
	assert_ne(get_viewport().gui_get_hovered_control(), menu.enter_button, "the menu under a screen gets no mouse")


func test_newer_character_save_shows_update_message_then_opens_screen_and_keeps_file() -> void:
	var path: String = CharacterProfile.directory() + "solo.json"
	var backup: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var raw: String = '{"save_version": %d, "total_xp": 9000}' % (SaveFile.CURRENT_VERSION + 1)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(raw)
	file.close()
	menu.loadout_button.grab_focus()
	menu.loadout_button.pressed.emit()
	assert_eq(UI.top(), &"", "the message comes before the character screen")
	assert_true(menu.error_dialog.visible)
	assert_eq(menu.error_dialog.message_label.text, MainMenu.NEWER_SAVE)
	menu.error_dialog.action_button.pressed.emit()
	assert_eq(UI.top(), &"character")
	var screen: CharacterScreen = _top_screen() as CharacterScreen
	assert_true(screen.profile.saved_by_newer_version)
	screen._close()
	screen._close()
	assert_eq(FileAccess.get_file_as_string(path), raw, "the newer save is never changed")
	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(backup)
		file.close()


func test_research_opens_solo_profile_and_back_restores_menu_focus() -> void:
	menu.research_button.grab_focus()
	menu.research_button.pressed.emit()
	assert_eq(UI.top(), &"research")
	var screen: ResearchScreen = _top_screen() as ResearchScreen
	assert_eq(screen.profile.id, &"solo")
	assert_true(screen.is_ancestor_of(get_viewport().gui_get_focus_owner()))
	screen.back()
	assert_eq(UI.top(), &"")
	assert_true(menu.research_button.has_focus())


func test_newer_save_message_then_opens_research_not_loadout() -> void:
	var path: String = CharacterProfile.directory() + "solo.json"
	var backup: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var raw: String = '{"save_version": %d, "total_xp": 9000}' % (SaveFile.CURRENT_VERSION + 1)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(raw)
	file.close()
	menu.research_button.grab_focus()
	menu.research_button.pressed.emit()
	assert_eq(UI.top(), &"", "the message comes first")
	menu.error_dialog.action_button.pressed.emit()
	assert_eq(UI.top(), &"research")
	var screen: ResearchScreen = _top_screen() as ResearchScreen
	screen.reset_all()
	screen.confirm()
	assert_true(screen.status.text.begins_with("Could not save"), "a newer save never takes new ranks")
	screen.back()
	screen.back()
	assert_eq(UI.top(), &"")
	assert_eq(FileAccess.get_file_as_string(path), raw, "the newer save is never changed")
	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(backup)
		file.close()

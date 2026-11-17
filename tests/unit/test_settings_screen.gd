## Exercises preference controls, paused navigation and live camera FOV with an isolated save.
extends GutTest

const SCREEN: PackedScene = preload("res://systems/ui/settings_screen.tscn")
const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const PATH: String = "user://test_settings_screen.cfg"

var _screen: SettingsScreen
var _old_path: String
var _old_values: Dictionary


func before_each() -> void:
	_old_path = Settings.config_path
	_old_values = Settings._values.duplicate(true)
	Settings.config_path = PATH
	Settings.reset_to_defaults()
	_screen = SCREEN.instantiate() as SettingsScreen
	add_child_autofree(_screen)


func after_each() -> void:
	while UI.top() != &"":
		UI.pop()
	get_tree().paused = false
	Settings._values = _old_values
	Settings._apply_all()
	Settings.config_path = _old_path
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _control(screen: SettingsScreen, key: StringName) -> Control:
	for page: SettingsPage in screen.pages:
		var control: Control = page.control_for(key)
		if control:
			return control
	return null


func _graphics(screen: SettingsScreen = _screen) -> SettingsPage:
	return screen.pages[2]


func test_tabs_come_from_data_with_key_bindings_once_at_the_end_of_controls() -> void:
	var tabs: TabContainer = _screen.get_node("%Tabs") as TabContainer
	var names: Array[String] = []
	for tab: Node in tabs.get_children():
		names.append(String(tab.name))
	assert_eq(names, ["Controls", "Aim", "Graphics", "Audio", "Accessibility"] as Array[String])
	assert_eq(_screen.pages[1].page, &"aim")
	assert_eq(_graphics().page, &"graphics")
	var controls: SettingsPage = _screen.pages[0]
	assert_eq(_screen.find_children("*", "KeyBindings", true, false).size(), 1)
	assert_eq(controls.get_child(controls.get_child_count() - 1), _screen.get_node("%KeyBindings"))
	for page: SettingsPage in _screen.pages:
		for row: SettingData in page.rows:
			assert_eq(row.page, page.page)


func test_sliders_save_every_preference() -> void:
	var cases: Array[Array] = [
		[&"mouse_sensitivity", &"aim", 5.0, 0.005],
		[&"ads_sensitivity_multiplier", &"aim", 125.0, 1.25],
		[&"fov", &"aim", 120.0, 120],
		[&"master_volume", &"audio", 35.0, 0.35],
		[&"music_volume", &"audio", 45.0, 0.45],
		[&"sfx_volume", &"audio", 55.0, 0.55],
	]
	for entry: Array in cases:
		var slider: HSlider = _control(_screen, entry[0]) as HSlider
		slider.value = entry[2]
		assert_almost_eq(float(Settings.get_value(entry[1], entry[0])), float(entry[3]), 0.000001)
		var saved: ConfigFile = ConfigFile.new()
		assert_eq(saved.load(PATH), OK)
		assert_almost_eq(float(saved.get_value(entry[1], entry[0])), float(entry[3]), 0.000001)
	assert_eq((_control(_screen, &"fov").get_node("../Number") as Label).text, "120")
	assert_eq((_control(_screen, &"mouse_sensitivity").get_node("../Number") as Label).text, "5.0")


func test_toggles_and_all_fps_options() -> void:
	for entry: Array in [[&"invert_y", &"aim"], [&"vsync", &"graphics"], [&"show_fps", &"graphics"]]:
		var toggle: CheckBox = _control(_screen, entry[0]) as CheckBox
		toggle.button_pressed = true
		assert_eq(Settings.get_value(entry[1], entry[0]), true)
		assert_eq(toggle.text, "On", "toggle state has a text cue")
		toggle.button_pressed = false
		assert_eq(Settings.get_value(entry[1], entry[0]), false)
		assert_eq(toggle.text, "Off")
	var option: OptionButton = _control(_screen, &"max_fps") as OptionButton
	var expected: Array[int] = [60, 120, 144, 165, 240, 0]
	for index: int in range(expected.size()):
		option.item_selected.emit(index)
		assert_eq(Settings.get_value(&"graphics", &"max_fps"), expected[index])
		assert_eq(option.selected, index)


func test_reopened_screen_shows_current_values() -> void:
	Settings.set_value(&"aim", &"mouse_sensitivity", 0.006)
	Settings.set_value(&"aim", &"invert_y", true)
	Settings.set_value(&"aim", &"fov", 75)
	Settings.set_value(&"graphics", &"max_fps", 144)
	Settings.set_value(&"audio", &"music_volume", 0.2)
	var reopened: SettingsScreen = SCREEN.instantiate() as SettingsScreen
	add_child_autofree(reopened)
	assert_almost_eq((_control(reopened, &"mouse_sensitivity") as HSlider).value, 6.0, 0.000001)
	assert_true((_control(reopened, &"invert_y") as CheckBox).button_pressed)
	assert_eq((_control(reopened, &"fov") as HSlider).value, 75.0)
	assert_eq((_control(reopened, &"max_fps") as OptionButton).selected, 2)
	assert_eq((_control(reopened, &"music_volume") as HSlider).value, 20.0)


func test_horizontal_fov_converts_and_updates_live_camera() -> void:
	var body: CharacterBody3D = CharacterBody3D.new()
	var head: PlayerCamera = PlayerCamera.new()
	var pivot: Node3D = Node3D.new()
	pivot.name = "RecoilPivot"
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	pivot.add_child(camera)
	head.add_child(pivot)
	body.add_child(head)
	add_child_autofree(body)
	assert_almost_eq(head.base_fov, 77.55, 0.1)
	assert_almost_eq(camera.fov, head.base_fov, 0.00001)
	Settings.set_value(&"aim", &"fov", 90)
	assert_almost_eq(head.base_fov, 58.72, 0.1)
	assert_almost_eq(camera.fov, head.base_fov, 0.00001)
	head.update_feel(1.0, false, false, 1.0, 45.0, 5.0)
	assert_eq(camera.fov, 45.0, "weapon ADS stays vertical")
	Settings.reset_to_defaults()
	assert_almost_eq(camera.fov, 77.55, 0.1)


func test_pause_settings_back_escape_and_resume() -> void:
	_screen.hide()
	var session: GameSession = SESSION.instantiate() as GameSession
	session.profile_id = &""
	session.rng_seed = 1234
	add_child_autofree(session)
	var pause: InputEventAction = InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	session._unhandled_input(pause)
	assert_true(get_tree().paused)
	var menu: PauseScreen = _top_screen() as PauseScreen
	assert_true(menu.resume_button.has_focus())
	menu.settings_button.grab_focus()
	menu.settings_button.pressed.emit()
	var settings: SettingsScreen = _top_screen() as SettingsScreen
	assert_eq(UI.top(), &"settings")
	assert_true(settings.is_visible_in_tree())
	assert_true(settings.can_process())
	assert_false(menu.is_visible_in_tree())
	var tabs: TabContainer = settings.get_node("Margin/Box/Tabs") as TabContainer
	tabs.current_tab = 1
	var slider: HSlider = _control(settings, &"fov") as HSlider
	slider.grab_focus()
	var right: InputEventKey = InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	await wait_process_frames(2)
	assert_eq(Settings.get_value(&"aim", &"fov"), 111, "keyboard control works while paused")
	assert_almost_eq(session.get_players()[0].camera_rig.base_fov, 78.53, 0.2)
	(settings.get_node("%Back") as Button).pressed.emit()
	assert_eq(UI.top(), &"pause")
	assert_true(get_tree().paused)
	assert_true(menu.settings_button.has_focus())
	menu.settings_button.pressed.emit()
	(_top_screen() as SettingsScreen)._input(pause)
	assert_eq(UI.top(), &"pause")
	assert_true(get_tree().paused)
	menu.resume_button.pressed.emit()
	assert_eq(UI.top(), &"")
	await wait_process_frames(1)
	assert_false(get_tree().paused)


func _top_screen() -> Node:
	return UI._stack.back()["layer"].get_child(0) if not UI._stack.is_empty() else null


func test_show_fps_is_only_a_hud_line() -> void:
	var hud: Hud = preload("res://systems/ui/hud.tscn").instantiate() as Hud
	add_child_autofree(hud)
	hud._process(0.0)
	assert_false(hud._fps_label.visible)
	Settings.set_value(&"graphics", &"show_fps", true)
	hud._process(0.0)
	assert_true(hud._fps_label.visible)
	assert_true(hud._fps_label.text.begins_with("FPS: "))
	assert_false(hud._fps_label.text.contains("\n"))


func test_standalone_screen_has_keyboard_focus_and_readable_hints() -> void:
	var tabs: TabContainer = _screen.get_node("%Tabs") as TabContainer
	assert_true(tabs.get_tab_bar().has_focus(), "a standalone settings screen starts with keyboard focus")
	for page: SettingsPage in _screen.pages:
		var hints: int = 0
		for child: Node in page.get_children():
			var label: Label = child as Label
			if label:
				hints += 1
				assert_false(label.text.is_empty())
				assert_gte(label.get_theme_font_size("font_size"), 24, "hints stay readable")
		assert_eq(hints, page.rows.size(), "each row explains itself")
	for index: int in range(tabs.get_tab_count()):
		tabs.current_tab = index
		await wait_process_frames(2)
		assert_lte(_screen.get_combined_minimum_size().x, 1600.0, "rows fit the game viewport")
		assert_lte(_screen.get_combined_minimum_size().y, 900.0, "footer remains visible")


func test_controller_back_closes_the_screen_and_emits_closed() -> void:
	watch_signals(_screen)
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	_screen._input(cancel)
	assert_signal_emitted(_screen, "closed")
	assert_false(_screen.visible)


func test_preset_dropdown_sets_and_follows_quality() -> void:
	var option: OptionButton = _graphics().control_for(&"preset") as OptionButton
	assert_eq(option.selected, Graphics.Preset.HIGH)
	option.item_selected.emit(Graphics.Preset.LOW)
	assert_eq(Settings.get_value(&"graphics", &"preset"), Graphics.Preset.LOW)
	assert_eq(Settings.get_value(&"graphics", &"shadows"), 0)
	Settings.set_value(&"graphics", &"shadows", 3)
	assert_eq(option.selected, Graphics.Preset.CUSTOM, "a hand change shows Custom")


func test_display_change_reverts_after_the_countdown() -> void:
	var page: SettingsPage = _graphics()
	var dialog: ConfirmationDialog = _screen.get_node("%KeepDialog") as ConfirmationDialog
	(page.control_for(&"display_mode") as OptionButton).item_selected.emit(2)
	assert_eq(Settings.get_value(&"graphics", &"display_mode"), 2)
	await wait_process_frames(1)
	assert_true(dialog.visible, "a display mode change asks to keep it")
	assert_true(dialog.dialog_text.contains("15 s"))
	for second: int in range(SettingsScreen.KEEP_SECONDS - 1):
		_screen._tick_keep()
	assert_eq(Settings.get_value(&"graphics", &"display_mode"), 2, "still waiting at 1 s left")
	assert_true(dialog.dialog_text.contains("1 s"))
	_screen._tick_keep()
	assert_eq(Settings.get_value(&"graphics", &"display_mode"), 0, "timeout goes back")
	assert_false(dialog.visible)
	assert_eq((page.control_for(&"display_mode") as OptionButton).selected, 0)


func test_display_change_kept_on_confirm_and_reverted_on_escape() -> void:
	var page: SettingsPage = _graphics()
	var dialog: ConfirmationDialog = _screen.get_node("%KeepDialog") as ConfirmationDialog
	(page.control_for(&"window_size") as OptionButton).item_selected.emit(3)
	dialog.confirmed.emit()
	for second: int in range(SettingsScreen.KEEP_SECONDS + 1):
		_screen._tick_keep()
	assert_eq(Settings.get_value(&"graphics", &"window_size"), 3, "kept after confirm")
	assert_false(dialog.visible)
	(page.control_for(&"window_size") as OptionButton).item_selected.emit(0)
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	watch_signals(_screen)
	_screen._input(cancel)
	assert_eq(Settings.get_value(&"graphics", &"window_size"), 3, "Esc goes back")
	assert_signal_not_emitted(_screen, "closed", "the first Esc only closes the prompt")
	assert_true(_screen.visible)


func test_unconfirmed_display_change_reverts_when_the_screen_is_freed() -> void:
	var page: SettingsPage = _graphics()
	(page.control_for(&"display_mode") as OptionButton).item_selected.emit(1)
	remove_child(_screen)
	assert_eq(Settings.get_value(&"graphics", &"display_mode"), 0)
	add_child(_screen)


func test_custom_preset_shows_but_cannot_be_picked() -> void:
	var option: OptionButton = _graphics().control_for(&"preset") as OptionButton
	assert_true(option.is_item_disabled(Graphics.Preset.CUSTOM))
	assert_false(option.is_item_disabled(Graphics.Preset.HIGH))


func test_non_display_rows_apply_without_asking() -> void:
	var page: SettingsPage = _graphics()
	(page.control_for(&"shadows") as OptionButton).item_selected.emit(0)
	assert_eq(Settings.get_value(&"graphics", &"shadows"), 0)
	assert_false((_screen.get_node("%KeepDialog") as ConfirmationDialog).visible)


func test_every_graphics_key_has_a_row() -> void:
	var page: SettingsPage = _graphics()
	for key: StringName in Graphics.DEFAULTS:
		assert_not_null(page.control_for(key), "%s is on the Graphics page" % key)

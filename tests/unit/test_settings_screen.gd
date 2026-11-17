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


func test_sliders_save_every_preference() -> void:
	var cases: Array[Array] = [
		[&"mouse_sensitivity", &"controls", 0.005, 0.005],
		[&"ads_sensitivity_multiplier", &"controls", 1.25, 1.25],
		[&"fov", &"video", 120.0, 120],
		[&"master_volume", &"audio", 35.0, 0.35],
		[&"music_volume", &"audio", 45.0, 0.45],
		[&"sfx_volume", &"audio", 55.0, 0.55],
	]
	for entry: Array in cases:
		var slider: HSlider = _screen.get_node("%" + entry[0]) as HSlider
		slider.value = entry[2]
		assert_almost_eq(float(Settings.get_value(entry[1], entry[0])), float(entry[3]), 0.000001)
		var saved: ConfigFile = ConfigFile.new()
		assert_eq(saved.load(PATH), OK)
		assert_almost_eq(float(saved.get_value(entry[1], entry[0])), float(entry[3]), 0.000001)
	assert_eq((_screen.get_node("%fov/../Number") as Label).text, "120.0")


func test_checkboxes_and_all_fps_options() -> void:
	for entry: Array in [[&"invert_y", &"controls"], [&"vsync", &"video"], [&"show_fps", &"video"]]:
		var check: CheckBox = _screen.get_node("%" + entry[0]) as CheckBox
		check.button_pressed = true
		assert_eq(Settings.get_value(entry[1], entry[0]), true)
		assert_true(check.text.ends_with("[On]"), "toggle state has a text cue")
		check.button_pressed = false
		assert_eq(Settings.get_value(entry[1], entry[0]), false)
		assert_true(check.text.ends_with("[Off]"), "toggle state has a text cue")
	var option: OptionButton = _screen.get_node("%max_fps") as OptionButton
	var expected: Array[int] = [60, 120, 144, 165, 240, 0]
	for index: int in range(expected.size()):
		option.item_selected.emit(index)
		assert_eq(Settings.get_value(&"video", &"max_fps"), expected[index])
		assert_eq(option.selected, index)


func test_start_values_external_changes_and_reset() -> void:
	Settings.set_value(&"controls", &"mouse_sensitivity", 0.006)
	Settings.set_value(&"controls", &"invert_y", true)
	Settings.set_value(&"video", &"fov", 75)
	Settings.set_value(&"video", &"max_fps", 144)
	Settings.set_value(&"video", &"vsync", true)
	Settings.set_value(&"video", &"show_fps", true)
	Settings.set_value(&"audio", &"music_volume", 0.2)
	var reopened: SettingsScreen = SCREEN.instantiate() as SettingsScreen
	add_child_autofree(reopened)
	assert_almost_eq((reopened.get_node("%mouse_sensitivity") as HSlider).value, 0.006, 0.000001)
	assert_true((reopened.get_node("%invert_y") as CheckBox).button_pressed)
	assert_eq((reopened.get_node("%fov") as HSlider).value, 75.0)
	assert_eq((reopened.get_node("%max_fps") as OptionButton).selected, 2)
	assert_eq((reopened.get_node("%music_volume") as HSlider).value, 20.0)
	(reopened.get_node("%Reset") as Button).pressed.emit()
	for key: StringName in SettingsScreen.SLIDERS:
		var section: StringName = SettingsScreen.SLIDERS[key][0]
		var scale: float = SettingsScreen.SLIDERS[key][1]
		assert_eq(Settings.get_value(section, key), Settings.DEFAULTS[section][key])
		assert_almost_eq(
			(reopened.get_node("%" + key) as HSlider).value, float(Settings.DEFAULTS[section][key]) * scale, 0.000001
		)
	for key: StringName in SettingsScreen.CHECKS:
		assert_false((reopened.get_node("%" + key) as CheckBox).button_pressed)
	assert_eq((reopened.get_node("%max_fps") as OptionButton).selected, 5)


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
	Settings.set_value(&"video", &"fov", 90)
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
	var slider: HSlider = settings.get_node("%fov") as HSlider
	slider.grab_focus()
	var right: InputEventKey = InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	await wait_process_frames(2)
	assert_eq(Settings.get_value(&"video", &"fov"), 111, "keyboard control works while paused")
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
	Settings.set_value(&"video", &"show_fps", true)
	hud._process(0.0)
	assert_true(hud._fps_label.visible)
	assert_true(hud._fps_label.text.begins_with("FPS: "))
	assert_false(hud._fps_label.text.contains("\n"))


func test_standalone_screen_has_keyboard_focus_and_readable_hints() -> void:
	var tabs: TabContainer = _screen.get_node("Margin/Box/Tabs") as TabContainer
	assert_true(tabs.get_tab_bar().has_focus(), "a standalone settings screen starts with keyboard focus")
	for tab: Control in tabs.get_children():
		var hints: int = 0
		var rows: Node = tab.get_child(0) if tab is ScrollContainer else tab
		for child: Node in rows.get_children():
			var label: Label = child as Label
			if label:
				hints += 1
				assert_false(label.text.is_empty())
				assert_gte(label.get_theme_font_size("font_size"), 24, "hints stay readable")
		assert_gt(hints, 0, "each tab explains its controls")
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

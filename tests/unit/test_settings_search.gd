## Settings screen search across pages, Revert to the opening values and Defaults for one page.
extends GutTest

const SCREEN: PackedScene = preload("res://systems/ui/settings_screen.tscn")
const PATH: String = "user://test_settings_search.cfg"

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


func test_search_shows_only_matching_rows_and_opens_their_page() -> void:
	var tabs: TabContainer = _screen.get_node("%Tabs") as TabContainer
	tabs.current_tab = 3
	(_screen.get_node("%Search") as LineEdit).text_changed.emit("texture")
	assert_eq(tabs.current_tab, 2, "jumps to Graphics")
	var visible: Array[StringName] = []
	for row: SettingData in _graphics().rows:
		if _graphics().control_for(row.key).get_parent().visible:
			visible.append(row.key)
	assert_eq(visible, [&"anisotropic"] as Array[StringName])
	assert_false((_screen.get_node("%KeyBindings") as Control).visible)
	_screen.search("MUSIC")
	assert_eq(tabs.current_tab, 3, "case does not matter")
	_screen.search("")
	assert_true(_graphics().control_for(&"glow").get_parent().visible)
	assert_true((_screen.get_node("%KeyBindings") as Control).visible)


func test_revert_restores_the_opening_values() -> void:
	Settings.set_value(&"graphics", &"preset", Graphics.Preset.LOW)
	Settings.set_value(&"audio", &"music_volume", 0.3)
	var screen: SettingsScreen = SCREEN.instantiate() as SettingsScreen
	add_child_autofree(screen)
	(_control(screen, &"preset") as OptionButton).item_selected.emit(Graphics.Preset.ULTRA)
	(_control(screen, &"music_volume") as HSlider).value = 90.0
	(_control(screen, &"fov") as HSlider).value = 80.0
	(screen.get_node("%Revert") as Button).pressed.emit()
	assert_eq(Settings.get_value(&"graphics", &"preset"), Graphics.Preset.LOW)
	assert_eq(Settings.get_value(&"graphics", &"shadows"), 0)
	assert_almost_eq(float(Settings.get_value(&"audio", &"music_volume")), 0.3, 0.0001)
	assert_eq(Settings.get_value(&"aim", &"fov"), 110)


func test_defaults_reset_only_the_open_page() -> void:
	Settings.set_value(&"audio", &"music_volume", 0.3)
	Settings.set_value(&"graphics", &"shadows", 0)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_K
	Settings.set_binding(&"jump", 0, key)
	var tabs: TabContainer = _screen.get_node("%Tabs") as TabContainer
	tabs.current_tab = 3
	(_screen.get_node("%Defaults") as Button).pressed.emit()
	assert_eq(Settings.get_value(&"audio", &"music_volume"), 0.8)
	assert_eq(Settings.get_value(&"graphics", &"shadows"), 0, "Graphics left alone")
	assert_eq(InputEvents.label(Settings.get_binding(&"jump")[0]), "K", "bindings left alone")
	tabs.current_tab = 0
	_screen.reset_page()
	assert_eq(InputEvents.label(Settings.get_binding(&"jump")[0]), "Space", "Controls resets bindings")
	assert_eq(Settings.get_value(&"graphics", &"shadows"), 0)

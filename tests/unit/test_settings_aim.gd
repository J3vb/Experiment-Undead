## Aim settings moved from the old controls and video sections, aiming sensitivity and resetting key bindings.
extends GutTest

const SETTINGS_SCRIPT: Script = preload("res://core/settings.gd")
const PATH: String = "user://test_settings_aim.cfg"

var _settings: Node
var _old_path: String
var _old_values: Dictionary
var _old_fps: int
var _old_bus_db: Array[float] = []


func before_each() -> void:
	_old_fps = Engine.max_fps
	_old_bus_db.clear()
	for bus: int in range(AudioServer.bus_count):
		_old_bus_db.append(AudioServer.get_bus_volume_db(bus))
	_old_path = Settings.config_path
	_old_values = Settings._values.duplicate(true)
	Settings.config_path = PATH
	_settings = SETTINGS_SCRIPT.new()
	_settings.config_path = PATH
	add_child_autofree(_settings)


func after_each() -> void:
	Settings._values = _old_values
	Settings.config_path = _old_path
	Settings._apply_all()
	Engine.max_fps = _old_fps
	for bus: int in range(_old_bus_db.size()):
		AudioServer.set_bus_volume_db(bus, _old_bus_db[bus])
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_old_controls_and_video_keys_load_into_aim() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("controls", "mouse_sensitivity", 0.005)
	config.set_value("controls", "ads_sensitivity_multiplier", 1.2)
	config.set_value("controls", "invert_y", true)
	config.set_value("video", "fov", 90)
	config.save(PATH)
	_settings.load_settings()
	assert_eq(_settings.get_value(&"aim", &"mouse_sensitivity"), 0.005)
	assert_eq(_settings.get_value(&"aim", &"ads_sensitivity_multiplier"), 1.2)
	assert_eq(_settings.get_value(&"aim", &"invert_y"), true)
	assert_eq(_settings.get_value(&"aim", &"fov"), 90)
	_settings.set_value(&"aim", &"fov", 100)
	var saved: ConfigFile = ConfigFile.new()
	saved.load(PATH)
	assert_eq(saved.get_value("aim", "fov"), 100, "new saves use the aim section")
	assert_false(saved.has_section("controls"))


func test_reset_bindings_restores_default_keys_only() -> void:
	_settings.set_value(&"audio", &"music_volume", 0.3)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_K
	_settings.set_binding(&"jump", 0, key)
	_settings.reset_bindings()
	assert_eq(InputEvents.label(_settings.get_binding(&"jump")[0]), "Space")
	assert_eq(_settings.get_value(&"audio", &"music_volume"), 0.3)


func test_aiming_sensitivity_setting_reaches_local_input() -> void:
	var local: LocalInput = LocalInput.new()
	add_child_autofree(local)
	assert_eq(local.ads_multiplier, 0.8)
	Settings.set_value(&"aim", &"ads_sensitivity_multiplier", 1.5)
	assert_eq(local.ads_multiplier, 1.5, "the slider changes look speed while aiming")
	Settings.reset_to_defaults()


func test_aim_sensitivities_clamp_to_the_slider_range() -> void:
	_settings.set_value(&"aim", &"ads_sensitivity_multiplier", 0.0)
	assert_eq(_settings.get_value(&"aim", &"ads_sensitivity_multiplier"), 0.2, "aiming can always turn")
	_settings.set_value(&"aim", &"ads_sensitivity_multiplier", 3.0)
	assert_eq(_settings.get_value(&"aim", &"ads_sensitivity_multiplier"), 2.0)
	_settings.set_value(&"aim", &"mouse_sensitivity", 0.0)
	assert_eq(_settings.get_value(&"aim", &"mouse_sensitivity"), 0.0002)

## Checks persisted preferences, application and LocalInput updates with isolated files.
extends GutTest

const SETTINGS_SCRIPT: Script = preload("res://core/settings.gd")
const PATH: String = "user://test_settings.cfg"

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


func test_defaults_for_missing_file() -> void:
	var expected: Dictionary = {
		&"aim": {&"fov": 110, &"mouse_sensitivity": 0.0022, &"ads_sensitivity_multiplier": 0.8, &"invert_y": false},
		&"graphics": Graphics.DEFAULTS,
		&"audio": {&"master_volume": 1.0, &"music_volume": 0.8, &"sfx_volume": 1.0},
		&"comfort":
		{
			&"head_bob": 0.6,
			&"weapon_bob": 1.0,
			&"sprint_fov": true,
			&"damage_effects": 1.0,
			&"centre_dot": false,
			&"shake_own_gun": 1.0,
			&"shake_hits": 1.0,
			&"flash_reduction": false,
		},
		&"accessibility":
		{
			&"text_scale": 1.0,
			&"toggle_ads": false,
			&"toggle_sprint": false,
			&"toggle_crouch": true,
			&"reduce_motion": false,
		},
		&"network": {&"last_address": "", &"last_port": 7777, &"open_to_friends": true},
	}
	for section: StringName in expected:
		for key: StringName in expected[section]:
			assert_eq(_settings.get_value(section, key), expected[section][key])
	assert_false(FileAccess.file_exists(PATH))


func test_comfort_sliders_clamp_and_flash_reduction_is_bool() -> void:
	for key: StringName in [&"shake_own_gun", &"shake_hits"]:
		_settings.set_value(&"comfort", key, -0.5)
		assert_eq(_settings.get_value(&"comfort", key), 0.0)
		_settings.set_value(&"comfort", key, 3.0)
		assert_eq(_settings.get_value(&"comfort", key), 1.0)
		_settings.set_value(&"comfort", key, 0.25)
		assert_eq(_settings.get_value(&"comfort", key), 0.25)
	_settings.set_value(&"comfort", &"flash_reduction", true)
	assert_true(_settings.get_value(&"comfort", &"flash_reduction"))
	_settings.set_value(&"comfort", &"flash_reduction", 1.0)
	assert_false(_settings.get_value(&"comfort", &"flash_reduction"), "a non-bool falls back to the default")


func test_save_load_round_trip() -> void:
	_settings.set_value(&"aim", &"mouse_sensitivity", 0.004)
	_settings.set_value(&"aim", &"invert_y", true)
	_settings.set_value(&"aim", &"fov", 100)
	_settings.set_value(&"audio", &"music_volume", 0.4)
	var loaded: Node = SETTINGS_SCRIPT.new()
	loaded.config_path = PATH
	add_child_autofree(loaded)
	assert_eq(loaded.get_value(&"aim", &"mouse_sensitivity"), 0.004)
	assert_eq(loaded.get_value(&"aim", &"invert_y"), true)
	assert_eq(loaded.get_value(&"aim", &"fov"), 100)
	assert_eq(loaded.get_value(&"audio", &"music_volume"), 0.4)


func test_clamps_values() -> void:
	for key: StringName in [&"master_volume", &"music_volume", &"sfx_volume"]:
		_settings.set_value(&"audio", key, -1.0)
		assert_eq(_settings.get_value(&"audio", key), 0.0)
		_settings.set_value(&"audio", key, 2.0)
		assert_eq(_settings.get_value(&"audio", key), 1.0)
	_settings.set_value(&"aim", &"fov", 20)
	assert_eq(_settings.get_value(&"aim", &"fov"), 70)
	_settings.set_value(&"aim", &"fov", 200)
	assert_eq(_settings.get_value(&"aim", &"fov"), 120)
	_settings.set_value(&"graphics", &"max_fps", -30)
	assert_eq(_settings.get_value(&"graphics", &"max_fps"), 0)


func test_network_address_and_port_survive_reload() -> void:
	_settings.set_value(&"network", &"last_address", " 192.168.1.20:7788 ")
	_settings.set_value(&"network", &"last_port", 7788)
	var loaded: Node = SETTINGS_SCRIPT.new()
	loaded.config_path = PATH
	add_child_autofree(loaded)
	assert_eq(loaded.get_value(&"network", &"last_address"), "192.168.1.20:7788")
	assert_eq(loaded.get_value(&"network", &"last_port"), 7788)
	assert_typeof(loaded.get_value(&"network", &"last_port"), TYPE_INT)


func test_network_port_clamps_and_bad_types_use_defaults() -> void:
	_settings.set_value(&"network", &"last_port", 0)
	assert_eq(_settings.get_value(&"network", &"last_port"), 1)
	_settings.set_value(&"network", &"last_port", 70000)
	assert_eq(_settings.get_value(&"network", &"last_port"), 64535, "the info port (+1000) must fit too")
	_settings.set_value(&"network", &"open_to_friends", "yes")
	assert_true(_settings.get_value(&"network", &"open_to_friends"), "worlds are open to friends by default")
	_settings.set_value(&"network", &"last_port", "7778")
	assert_eq(_settings.get_value(&"network", &"last_port"), 7777)
	_settings.set_value(&"network", &"last_address", 123)
	assert_eq(_settings.get_value(&"network", &"last_address"), "")
	_settings.set_value(&"network", &"last_port", NAN)
	assert_eq(_settings.get_value(&"network", &"last_port"), 7777)


func test_network_bad_saved_values_fall_back_to_defaults() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("network", "last_address", ["bad"])
	config.set_value("network", "last_port", false)
	config.save(PATH)
	_settings.load_settings()
	assert_eq(_settings.get_value(&"network", &"last_address"), "")
	assert_eq(_settings.get_value(&"network", &"last_port"), 7777)


func test_broken_file_falls_back_to_defaults() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[controls]\nmouse_sensitivity=0.5\n[broken")
	file.close()
	_settings.load_settings()
	assert_eq(_settings.get_value(&"aim", &"mouse_sensitivity"), 0.0022)
	assert_eq(_settings.get_value(&"aim", &"fov"), 110)


func test_unknown_keys_and_invalid_values_are_ignored() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("unknown", "key", 123)
	config.set_value("video", "unknown", 123)
	config.set_value("video", "fov", "bad")
	config.set_value("controls", "invert_y", "false")
	config.set_value("audio", "music_volume", 3.0)
	config.save(PATH)
	_settings.load_settings()
	assert_null(_settings.get_value(&"unknown", &"key"))
	assert_null(_settings.get_value(&"aim", &"unknown"))
	assert_eq(_settings.get_value(&"aim", &"fov"), 110)
	assert_eq(_settings.get_value(&"aim", &"invert_y"), false)
	assert_eq(_settings.get_value(&"audio", &"music_volume"), 1.0)
	_settings.set_value(&"unknown", &"key", 4)
	assert_null(_settings.get_value(&"unknown", &"key"))


func test_changed_signal_reports_clamped_value() -> void:
	watch_signals(_settings)
	_settings.set_value(&"aim", &"fov", 500)
	assert_signal_emitted_with_parameters(_settings, "changed", [&"aim", &"fov", 120])


func test_reset_applies_and_saves_defaults() -> void:
	_settings.set_value(&"audio", &"music_volume", 0.2)
	_settings.reset_to_defaults()
	assert_eq(_settings.get_value(&"audio", &"music_volume"), 0.8)
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(PATH), OK)
	assert_eq(config.get_value("audio", "music_volume"), 0.8)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), linear_to_db(0.8), 0.001)


func test_audio_applies_on_load_and_change() -> void:
	for key: StringName in {&"master_volume": &"Master", &"music_volume": &"Music", &"sfx_volume": &"SFX"}:
		var bus: int = AudioServer.get_bus_index(_settings.AUDIO_BUSES[key])
		_settings.set_value(&"audio", key, 0.25)
		assert_almost_eq(AudioServer.get_bus_volume_db(bus), linear_to_db(0.25), 0.001)
		AudioServer.set_bus_volume_db(bus, 0.0)
		_settings.load_settings()
		assert_almost_eq(AudioServer.get_bus_volume_db(bus), linear_to_db(0.25), 0.001)


func test_headless_does_not_apply_video() -> void:
	if DisplayServer.get_name() != "headless":
		return
	Engine.max_fps = 123
	_settings.set_value(&"graphics", &"max_fps", 60)
	_settings.set_value(&"graphics", &"vsync", true)
	_settings.load_settings()
	assert_eq(Engine.max_fps, 123)


func test_local_input_uses_loaded_controls_and_updates() -> void:
	_settings.set_value(&"aim", &"mouse_sensitivity", 0.004)
	Settings.load_settings()
	var local: LocalInput = LocalInput.new()
	add_child_autofree(local)
	local._look_accum = Vector2(10.0, 5.0)
	assert_almost_eq(local.sample(1).look, Vector2(0.04, 0.02), Vector2.ONE * 0.000001)
	Settings.set_value(&"aim", &"mouse_sensitivity", 0.01)
	Settings.set_value(&"aim", &"invert_y", true)
	local._look_accum = Vector2(10.0, 5.0)
	assert_almost_eq(local.sample(2).look, Vector2(0.1, -0.05), Vector2.ONE * 0.000001)
	Settings.reset_to_defaults()
	assert_eq(local.mouse_sensitivity, 0.0022)
	assert_false(local.invert_y)


func test_old_video_keys_load_into_graphics() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("video", "fov", 95)
	config.set_value("video", "vsync", true)
	config.set_value("video", "max_fps", 144)
	config.set_value("video", "show_fps", true)
	config.save(PATH)
	_settings.load_settings()
	assert_eq(_settings.get_value(&"aim", &"fov"), 95)
	assert_eq(_settings.get_value(&"graphics", &"vsync"), true)
	assert_eq(_settings.get_value(&"graphics", &"max_fps"), 144)
	assert_eq(_settings.get_value(&"graphics", &"show_fps"), true)
	_settings.set_value(&"graphics", &"vsync", false)
	var saved: ConfigFile = ConfigFile.new()
	saved.load(PATH)
	assert_eq(saved.get_value("graphics", "vsync"), false, "the new section wins once saved")
	_settings.load_settings()
	assert_eq(_settings.get_value(&"graphics", &"vsync"), false)


func test_preset_writes_its_keys_and_a_hand_change_makes_it_custom() -> void:
	_settings.set_value(&"graphics", &"preset", Graphics.Preset.LOW)
	for key: StringName in Graphics.PRESETS[Graphics.Preset.LOW]:
		assert_eq(_settings.get_value(&"graphics", key), Graphics.PRESETS[Graphics.Preset.LOW][key], key)
	_settings.set_value(&"graphics", &"preset", Graphics.Preset.HIGH)
	assert_eq(_settings.get_value(&"graphics", &"aa"), Graphics.Aa.MSAA_4X)
	assert_eq(_settings.get_value(&"graphics", &"preset"), Graphics.Preset.HIGH, "applying a preset keeps it")
	_settings.set_value(&"graphics", &"brightness", 1.2)
	assert_eq(_settings.get_value(&"graphics", &"preset"), Graphics.Preset.HIGH, "brightness is not part of presets")
	_settings.set_value(&"graphics", &"shadows", 0)
	assert_eq(_settings.get_value(&"graphics", &"preset"), Graphics.Preset.CUSTOM)
	assert_eq(_settings.get_value(&"graphics", &"shadows"), 0, "picking Custom keeps the hand-set values")


func test_graphics_values_clamp() -> void:
	_settings.set_value(&"graphics", &"aa", 99)
	assert_eq(_settings.get_value(&"graphics", &"aa"), Graphics.Aa.TAA)
	_settings.set_value(&"graphics", &"render_scale", 0.1)
	assert_eq(_settings.get_value(&"graphics", &"render_scale"), 0.5)
	_settings.set_value(&"graphics", &"brightness", 9.0)
	assert_eq(_settings.get_value(&"graphics", &"brightness"), 1.5)


func test_gore_defaults_to_full_clamps_and_stays_out_of_presets() -> void:
	assert_eq(_settings.get_value(&"graphics", &"gore"), Impact.Gore.FULL)
	_settings.set_value(&"graphics", &"gore", 7)
	assert_eq(_settings.get_value(&"graphics", &"gore"), Impact.Gore.FULL)
	_settings.set_value(&"graphics", &"gore", -3)
	assert_eq(_settings.get_value(&"graphics", &"gore"), Impact.Gore.OFF)
	_settings.set_value(&"graphics", &"preset", Graphics.Preset.LOW)
	assert_eq(_settings.get_value(&"graphics", &"gore"), Impact.Gore.OFF, "a preset leaves gore alone")

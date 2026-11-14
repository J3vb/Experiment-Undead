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
		&"controls": {&"mouse_sensitivity": 0.0022, &"ads_sensitivity_multiplier": 0.8, &"invert_y": false},
		&"video": {&"fov": 90, &"max_fps": 0, &"vsync": false, &"show_fps": false},
		&"audio": {&"master_volume": 1.0, &"music_volume": 0.8, &"sfx_volume": 1.0},
	}
	for section: StringName in expected:
		for key: StringName in expected[section]:
			assert_eq(_settings.get_value(section, key), expected[section][key])
	assert_false(FileAccess.file_exists(PATH))


func test_save_load_round_trip() -> void:
	_settings.set_value(&"controls", &"mouse_sensitivity", 0.004)
	_settings.set_value(&"controls", &"invert_y", true)
	_settings.set_value(&"video", &"fov", 100)
	_settings.set_value(&"audio", &"music_volume", 0.4)
	var loaded: Node = SETTINGS_SCRIPT.new()
	loaded.config_path = PATH
	add_child_autofree(loaded)
	assert_eq(loaded.get_value(&"controls", &"mouse_sensitivity"), 0.004)
	assert_eq(loaded.get_value(&"controls", &"invert_y"), true)
	assert_eq(loaded.get_value(&"video", &"fov"), 100)
	assert_eq(loaded.get_value(&"audio", &"music_volume"), 0.4)


func test_clamps_values() -> void:
	for key: StringName in [&"master_volume", &"music_volume", &"sfx_volume"]:
		_settings.set_value(&"audio", key, -1.0)
		assert_eq(_settings.get_value(&"audio", key), 0.0)
		_settings.set_value(&"audio", key, 2.0)
		assert_eq(_settings.get_value(&"audio", key), 1.0)
	_settings.set_value(&"video", &"fov", 20)
	assert_eq(_settings.get_value(&"video", &"fov"), 70)
	_settings.set_value(&"video", &"fov", 200)
	assert_eq(_settings.get_value(&"video", &"fov"), 110)
	_settings.set_value(&"video", &"max_fps", -30)
	assert_eq(_settings.get_value(&"video", &"max_fps"), 0)


func test_broken_file_falls_back_to_defaults() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[controls]\nmouse_sensitivity=0.5\n[broken")
	file.close()
	_settings.load_settings()
	assert_eq(_settings.get_value(&"controls", &"mouse_sensitivity"), 0.0022)
	assert_eq(_settings.get_value(&"video", &"fov"), 90)


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
	assert_null(_settings.get_value(&"video", &"unknown"))
	assert_eq(_settings.get_value(&"video", &"fov"), 90)
	assert_eq(_settings.get_value(&"controls", &"invert_y"), false)
	assert_eq(_settings.get_value(&"audio", &"music_volume"), 1.0)
	_settings.set_value(&"unknown", &"key", 4)
	assert_null(_settings.get_value(&"unknown", &"key"))


func test_changed_signal_reports_clamped_value() -> void:
	watch_signals(_settings)
	_settings.set_value(&"video", &"fov", 500)
	assert_signal_emitted_with_parameters(_settings, "changed", [&"video", &"fov", 110])


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
	_settings.set_value(&"video", &"max_fps", 60)
	_settings.set_value(&"video", &"vsync", true)
	_settings.load_settings()
	assert_eq(Engine.max_fps, 123)


func test_local_input_uses_loaded_controls_and_updates() -> void:
	_settings.set_value(&"controls", &"mouse_sensitivity", 0.004)
	Settings.load_settings()
	var local: LocalInput = LocalInput.new()
	add_child_autofree(local)
	local._look_accum = Vector2(10.0, 5.0)
	assert_almost_eq(local.sample(1).look, Vector2(0.04, 0.02), Vector2.ONE * 0.000001)
	Settings.set_value(&"controls", &"mouse_sensitivity", 0.01)
	Settings.set_value(&"controls", &"invert_y", true)
	local._look_accum = Vector2(10.0, 5.0)
	assert_almost_eq(local.sample(2).look, Vector2(0.1, -0.05), Vector2.ONE * 0.000001)
	Settings.reset_to_defaults()
	assert_eq(local.mouse_sensitivity, 0.0022)
	assert_false(local.invert_y)

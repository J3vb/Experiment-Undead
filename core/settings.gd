## Persists player options and applies local video and audio preferences.
extends Node

signal changed(section: StringName, key: StringName, value: Variant)

const DEFAULTS: Dictionary = {
	&"controls": {&"mouse_sensitivity": 0.0022, &"ads_sensitivity_multiplier": 0.8, &"invert_y": false},
	&"video": {&"fov": 110, &"max_fps": 0, &"vsync": false, &"show_fps": false},
	&"audio": {&"master_volume": 1.0, &"music_volume": 0.8, &"sfx_volume": 1.0},
}
const AUDIO_BUSES: Dictionary = {&"master_volume": &"Master", &"music_volume": &"Music", &"sfx_volume": &"SFX"}

var config_path: String = "user://settings.cfg"
var _values: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	load_settings()


func get_value(section: StringName, key: StringName) -> Variant:
	return _values.get(section, {}).get(key)


func set_value(section: StringName, key: StringName, value: Variant) -> void:
	if not DEFAULTS.has(section) or not DEFAULTS[section].has(key):
		return
	var normalized: Variant = _normalize(section, key, value)
	if _values[section][key] == normalized:
		return
	_values[section][key] = normalized
	_apply(section, key)
	changed.emit(section, key, normalized)
	_save()


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	_values = DEFAULTS.duplicate(true)
	if _load_config(config) == OK:
		for section: StringName in DEFAULTS:
			for key: StringName in DEFAULTS[section]:
				_values[section][key] = _normalize(section, key, config.get_value(section, key, DEFAULTS[section][key]))
	_apply_all()


func _load_config(config: ConfigFile) -> Error:
	if not FileAccess.file_exists(config_path):
		return ERR_FILE_NOT_FOUND
	# ConfigFile logs malformed input; this synchronous read must fall back quietly.
	var print_errors: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var result: Error = config.load(config_path)
	Engine.print_error_messages = print_errors
	return result


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate(true)
	_apply_all()
	_save()


func _normalize(section: StringName, key: StringName, value: Variant) -> Variant:
	var fallback: Variant = DEFAULTS[section][key]
	if fallback is bool:
		return value if value is bool else fallback
	if not (value is float or value is int) or not is_finite(float(value)):
		return fallback
	if section == &"audio":
		return clampf(float(value), 0.0, 1.0)
	if key == &"fov":
		return clampi(int(value), 70, 120)
	if key == &"max_fps":
		return maxi(int(value), 0)
	return maxf(float(value), 0.0)


func _apply_all() -> void:
	for section: StringName in DEFAULTS:
		for key: StringName in DEFAULTS[section]:
			_apply(section, key)
			changed.emit(section, key, _values[section][key])


func _apply(section: StringName, key: StringName) -> void:
	var value: Variant = _values[section][key]
	if section == &"video" and DisplayServer.get_name() != "headless":
		if key == &"max_fps":
			Engine.max_fps = int(value)
		elif key == &"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
	elif section == &"audio":
		var bus: int = AudioServer.get_bus_index(AUDIO_BUSES[key])
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, linear_to_db(float(value)))


func _save() -> void:
	var config: ConfigFile = ConfigFile.new()
	for section: StringName in DEFAULTS:
		for key: StringName in DEFAULTS[section]:
			config.set_value(section, key, _values[section][key])
	config.save(config_path)

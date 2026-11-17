## Persists player options and key bindings, and applies local video and audio preferences.
extends Node

signal changed(section: StringName, key: StringName, value: Variant)

const DEFAULTS: Dictionary = {
	&"controls": {&"mouse_sensitivity": 0.0022, &"ads_sensitivity_multiplier": 0.8, &"invert_y": false},
	&"video": {&"fov": 110, &"max_fps": 0, &"vsync": false, &"show_fps": false},
	&"audio": {&"master_volume": 1.0, &"music_volume": 0.8, &"sfx_volume": 1.0},
	&"network": {&"last_address": "", &"last_port": 7777},
}
const AUDIO_BUSES: Dictionary = {&"master_volume": &"Master", &"music_volume": &"Music", &"sfx_volume": &"SFX"}
## Pause is locked so a player can never lock themselves out of the menus.
const LOCKED_ACTIONS: Array[StringName] = [&"pause"]
const BINDING_SLOTS: int = 2
const MOUSE_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "Left mouse",
	MOUSE_BUTTON_RIGHT: "Right mouse",
	MOUSE_BUTTON_MIDDLE: "Middle mouse",
	MOUSE_BUTTON_WHEEL_UP: "Wheel up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
	MOUSE_BUTTON_WHEEL_LEFT: "Wheel left",
	MOUSE_BUTTON_WHEEL_RIGHT: "Wheel right",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}

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
	_reset_all_bindings()
	if _load_config(config) == OK:
		for section: StringName in DEFAULTS:
			for key: StringName in DEFAULTS[section]:
				_values[section][key] = _normalize(section, key, config.get_value(section, key, DEFAULTS[section][key]))
		_load_bindings(config)
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
	_reset_all_bindings()
	_apply_all()
	_save()


func _normalize(section: StringName, key: StringName, value: Variant) -> Variant:
	var fallback: Variant = DEFAULTS[section][key]
	if fallback is bool:
		return value if value is bool else fallback
	if fallback is String:
		return value.strip_edges() if value is String else fallback
	if not (value is float or value is int) or not is_finite(float(value)):
		return fallback
	var normalized: Variant = maxf(float(value), 0.0)
	if key == &"last_port":
		normalized = clampi(int(value), 1, 65535)
	elif section == &"audio":
		normalized = clampf(float(value), 0.0, 1.0)
	elif key == &"fov":
		normalized = clampi(int(value), 70, 120)
	elif key == &"max_fps":
		normalized = maxi(int(value), 0)
	return normalized


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
	for action: StringName in rebindable_actions():
		var events: Array[InputEvent] = get_binding(action)
		if not _same_events(events, _default_binding(action)):
			config.set_value(&"bindings", action, events.map(_event_to_value))
	config.save(config_path)


## Input actions the player may rebind, in input map order. Defaults live in project.godot.
func rebindable_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	for action: StringName in InputMap.get_actions():
		if can_rebind(action):
			actions.append(action)
	return actions


func can_rebind(action: StringName) -> bool:
	return (
		not String(action).begins_with("ui_")
		and action not in LOCKED_ACTIONS
		and ProjectSettings.has_setting("input/" + action)
		and InputMap.has_action(action)
	)


## Keyboard and mouse events of an action (main slot first); controller events are left out.
func get_binding(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	if InputMap.has_action(action):
		for event: InputEvent in InputMap.action_get_events(action):
			if _clean_event(event):
				events.append(event)
	return events


## Puts a key or mouse button in a slot. Returns false if the action or event cannot be bound.
func set_binding(action: StringName, slot: int, event: InputEvent) -> bool:
	var clean: InputEvent = _clean_event(event)
	if not can_rebind(action) or clean == null or slot < 0 or slot >= BINDING_SLOTS:
		return false
	var events: Array[InputEvent] = get_binding(action)
	if slot < events.size():
		events[slot] = clean
	else:
		events.append(clean)
	_replace_binding(action, events)
	_binding_changed(action)
	return true


## The other action that already uses this key or button, or &"" when it is free.
func binding_owner(event: InputEvent, except_action: StringName = &"") -> StringName:
	for action: StringName in InputMap.get_actions():
		if action == except_action or String(action).begins_with("ui_"):
			continue
		for bound: InputEvent in get_binding(action):
			if _same_event(bound, event):
				return action
	return &""


## Binds the event and gives its current owner this slot's old key (or nothing if the slot was empty).
func swap_binding(action: StringName, slot: int, event: InputEvent) -> bool:
	var owner: StringName = binding_owner(event, action)
	if not can_rebind(action) or (owner != &"" and not can_rebind(owner)):
		return false
	var mine: Array[InputEvent] = get_binding(action)
	var old: InputEvent = mine[slot] if slot >= 0 and slot < mine.size() else null
	if not set_binding(action, slot, event):
		return false
	if owner != &"":
		var theirs: Array[InputEvent] = get_binding(owner)
		var index: int = theirs.find_custom(_same_event.bind(event))
		if old:
			theirs[index] = old
		else:
			theirs.remove_at(index)
		_replace_binding(owner, theirs)
		_binding_changed(owner)
	return true


## Puts the default keys back; an action that took one of them gets this slot's current key instead.
func reset_binding(action: StringName) -> void:
	if not can_rebind(action):
		return
	var defaults: Array[InputEvent] = _default_binding(action)
	for slot: int in defaults.size():
		swap_binding(action, slot, defaults[slot])
	_replace_binding(action, defaults)
	_binding_changed(action)


## What to show for a key or button: the letter on the player's own keyboard layout.
func event_label(event: InputEvent) -> String:
	var key: InputEventKey = event as InputEventKey
	if key:
		if DisplayServer.get_name() == "headless":
			return key.as_text_physical_keycode()
		var local: Key = DisplayServer.keyboard_get_label_from_physical(key.physical_keycode)
		return OS.get_keycode_string(local) if local != KEY_NONE else key.as_text_physical_keycode()
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button:
		return MOUSE_NAMES.get(button.button_index, "Mouse %d" % button.button_index)
	return "?"


func _binding_changed(action: StringName) -> void:
	changed.emit(&"bindings", action, null)
	_save()


func _default_binding(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	var data: Dictionary = ProjectSettings.get_setting("input/" + action, {})
	for event: InputEvent in data.get("events", []):
		var clean: InputEvent = _clean_event(event)
		if clean:
			events.append(clean)
	return events


func _replace_binding(action: StringName, events: Array[InputEvent]) -> void:
	for old: InputEvent in get_binding(action):
		InputMap.action_erase_event(action, old)
	var kept: Array[InputEvent] = []
	for event: InputEvent in events:
		if (
			kept.size() < BINDING_SLOTS
			and not kept.any(func(other: InputEvent) -> bool: return _same_event(other, event))
		):
			kept.append(event)
			InputMap.action_add_event(action, event)


func _reset_all_bindings() -> void:
	for action: StringName in rebindable_actions():
		_replace_binding(action, _default_binding(action))


func _load_bindings(config: ConfigFile) -> void:
	if not config.has_section(&"bindings"):
		return
	for action: String in config.get_section_keys(&"bindings"):
		var value: Variant = config.get_value(&"bindings", action)
		var events: Array[InputEvent] = []
		var valid: bool = value is Array and value.size() <= BINDING_SLOTS
		if valid:
			for entry: Variant in value:
				events.append(_event_from_value(entry))
		if not can_rebind(StringName(action)):
			Log.warn(&"settings", &"binding_unknown_action", {"action": action})
		elif not valid or events.has(null):
			Log.warn(&"settings", &"binding_malformed", {"action": action})
		else:
			_replace_binding(StringName(action), events)


func _event_from_value(value: Variant) -> InputEvent:
	var entry: Dictionary = value if value is Dictionary else {}
	if entry.get("type") == "key" and entry.get("physical") is int:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = entry["physical"]
		return _clean_event(key)
	if entry.get("type") == "mouse" and entry.get("button") is int:
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = entry["button"]
		return _clean_event(button)
	return null


func _event_to_value(event: InputEvent) -> Dictionary:
	var key: InputEventKey = event as InputEventKey
	if key:
		return {"type": "key", "physical": int(key.physical_keycode)}
	return {"type": "mouse", "button": int((event as InputEventMouseButton).button_index)}


## A plain physical key or mouse button with no modifiers, or null if it cannot be bound (Esc, controller).
func _clean_event(event: InputEvent) -> InputEvent:
	var key: InputEventKey = event as InputEventKey
	if key:
		var physical: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if physical == KEY_NONE or physical == KEY_ESCAPE:
			return null
		var clean_key: InputEventKey = InputEventKey.new()
		clean_key.physical_keycode = physical
		return clean_key
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button and button.button_index != MOUSE_BUTTON_NONE:
		var clean_button: InputEventMouseButton = InputEventMouseButton.new()
		clean_button.button_index = button.button_index
		return clean_button
	return null


func _same_event(a: InputEvent, b: InputEvent) -> bool:
	var clean_a: InputEvent = _clean_event(a)
	var clean_b: InputEvent = _clean_event(b)
	if clean_a == null or clean_b == null:
		return false
	return _event_to_value(clean_a) == _event_to_value(clean_b)


func _same_events(a: Array[InputEvent], b: Array[InputEvent]) -> bool:
	if a.size() != b.size():
		return false
	for index: int in a.size():
		if not _same_event(a[index], b[index]):
			return false
	return true

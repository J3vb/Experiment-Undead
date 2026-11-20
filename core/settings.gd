## Persists player options and key bindings, and applies audio; graphics apply through Graphics.
extends Node

signal changed(section: StringName, key: StringName, value: Variant)

const DEFAULTS: Dictionary = {
	&"aim": {&"fov": 110, &"mouse_sensitivity": 0.0022, &"ads_sensitivity_multiplier": 0.8, &"invert_y": false},
	&"graphics": Graphics.DEFAULTS,
	&"audio": {&"master_volume": 1.0, &"music_volume": 0.8, &"sfx_volume": 1.0},
	&"accessibility":
	{
		&"text_scale": 1.0,
		&"toggle_ads": false,
		&"toggle_sprint": false,
		&"toggle_crouch": true,
		&"reduce_motion": false,
		&"damage_numbers": "off",
	},
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
	&"network":
	{
		&"last_address": "",
		&"last_port": 7777,
		&"open_to_friends": true,
		&"upnp": true,
		&"world_name": "Lantern Post",
	},
}
## Min and max of float options that are not 0 to 1.
const RANGES: Dictionary = {
	&"text_scale": [0.8, 1.5],
	&"ads_sensitivity_multiplier": [0.2, 2.0],
	&"mouse_sensitivity": [0.0002, 0.02],
}
## Comfort column of docs/design/controls.md; keys other threads have not added yet are skipped by set_value.
const COMFORT_PRESET: Dictionary = {
	&"head_bob": 0.0,
	&"weapon_bob": 0.5,
	&"sprint_fov": false,
	&"damage_effects": 0.5,
	&"centre_dot": true,
	&"shake_own_gun": 0.25,
	&"shake_hits": 0.25,
	&"flash_reduction": true,
}
const AUDIO_BUSES: Dictionary = {&"master_volume": &"Master", &"music_volume": &"Music", &"sfx_volume": &"SFX"}
## Pause is locked so a player can never lock themselves out of the menus.
const LOCKED_ACTIONS: Array[StringName] = [&"pause"]
const BINDING_SLOTS: int = 2

var config_path: String = "user://settings.cfg"
var _values: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	_copy_old_name_data()
	load_settings()


## The game was renamed: bring the player's files over before anything reads them.
func _copy_old_name_data() -> void:
	var copied: int = OldNameData.copy_if_new(OldNameData.old_dir(), OS.get_user_data_dir())
	if copied > 0:
		Log.info(&"save", &"old_name_data_copied", {"files": copied, "from": OldNameData.old_dir()})


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
	if section == &"graphics":
		var linked: Dictionary = Graphics.linked_changes(key, normalized, _values[section])
		for other: StringName in linked:
			set_value(section, other, linked[other])


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	_values = DEFAULTS.duplicate(true)
	_reset_all_bindings()
	if _load_config(config) == OK:
		for section: StringName in DEFAULTS:
			for key: StringName in DEFAULTS[section]:
				# Keys moved out of the old video and controls sections still load from there.
				var old: Variant = config.get_value(
					&"video", key, config.get_value(&"controls", key, DEFAULTS[section][key])
				)
				_values[section][key] = _normalize(section, key, config.get_value(section, key, old))
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
		# The info port (game port + 1000) must fit too.
		normalized = clampi(int(value), 1, 64535)
	elif section == &"audio" or section == &"comfort":
		normalized = clampf(float(value), 0.0, 1.0)
	elif key == &"fov":
		normalized = clampi(int(value), 70, 120)
	elif RANGES.has(key):
		normalized = clampf(float(value), RANGES[key][0], RANGES[key][1])
	elif section == &"graphics":
		normalized = Graphics.normalize(key, value)
	return normalized


func _apply_all() -> void:
	for section: StringName in DEFAULTS:
		for key: StringName in DEFAULTS[section]:
			_apply(section, key)
			changed.emit(section, key, _values[section][key])
	changed.emit(&"bindings", &"", null)


func _apply(section: StringName, key: StringName) -> void:
	var value: Variant = _values[section][key]
	if section == &"graphics":
		Graphics.apply(key, _values[section], get_tree().root)
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
		if not InputEvents.same_list(events, _default_binding(action)):
			config.set_value(&"bindings", action, events.map(InputEvents.to_value))
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
			if InputEvents.clean(event):
				events.append(event)
	return events


## Puts a key or mouse button in a slot. Returns false if the action or event cannot be bound.
func set_binding(action: StringName, slot: int, event: InputEvent) -> bool:
	var clean: InputEvent = InputEvents.clean(event)
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
			if InputEvents.same(bound, event):
				return action
	return &""


## Binds the event and gives its current owner this slot's old key (or nothing if the slot was empty).
func swap_binding(action: StringName, slot: int, event: InputEvent) -> bool:
	var taken_by: StringName = binding_owner(event, action)
	if not can_rebind(action) or (taken_by != &"" and not can_rebind(taken_by)):
		return false
	var mine: Array[InputEvent] = get_binding(action)
	var old: InputEvent = mine[slot] if slot >= 0 and slot < mine.size() else null
	if not set_binding(action, slot, event):
		return false
	if taken_by != &"":
		var theirs: Array[InputEvent] = get_binding(taken_by)
		var index: int = theirs.find_custom(InputEvents.same.bind(event))
		if old:
			theirs[index] = old
		else:
			theirs.remove_at(index)
		_replace_binding(taken_by, theirs)
		_binding_changed(taken_by)
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


## The main key or mouse button of an action, for prompts; "?" when it has none.
func key_name(action: StringName) -> String:
	var events: Array[InputEvent] = get_binding(action)
	return InputEvents.label(events[0]) if not events.is_empty() else "?"


func _binding_changed(action: StringName) -> void:
	changed.emit(&"bindings", action, null)
	_save()


func _default_binding(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	var data: Dictionary = ProjectSettings.get_setting("input/" + action, {})
	for event: InputEvent in data.get("events", []):
		var clean: InputEvent = InputEvents.clean(event)
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
			and not kept.any(func(other: InputEvent) -> bool: return InputEvents.same(other, event))
		):
			kept.append(event)
			InputMap.action_add_event(action, event)


func apply_comfort_preset() -> void:
	for key: StringName in COMFORT_PRESET:
		set_value(&"comfort", key, COMFORT_PRESET[key])


func reset_bindings() -> void:
	_reset_all_bindings()
	_binding_changed(&"")


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
				events.append(InputEvents.from_value(entry))
		if not can_rebind(StringName(action)):
			Log.warn(&"settings", &"binding_unknown_action", {"action": action})
		elif not valid or events.has(null):
			Log.warn(&"settings", &"binding_malformed", {"action": action})
		else:
			_replace_binding(StringName(action), events)

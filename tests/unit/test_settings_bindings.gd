## Checks key binding save, load, conflicts, swap and reset with an isolated settings file.
extends GutTest

const SETTINGS_SCRIPT: Script = preload("res://core/settings.gd")
const PATH: String = "user://test_settings_bindings.cfg"

var _settings: Node


func before_each() -> void:
	_remove_file()
	_settings = _new_settings()


func after_each() -> void:
	_settings._reset_all_bindings()
	_remove_file()


func _new_settings() -> Node:
	var settings: Node = SETTINGS_SCRIPT.new()
	settings.config_path = PATH
	add_child_autofree(settings)
	return settings


func _remove_file() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _key(code: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = code
	return key


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	return event


func _codes(action: StringName) -> Array[int]:
	var codes: Array[int] = []
	for event: InputEvent in _settings.get_binding(action):
		var key: InputEventKey = event as InputEventKey
		codes.append(int(key.physical_keycode) if key else -int((event as InputEventMouseButton).button_index))
	return codes


func _write_config(section_values: Dictionary) -> void:
	var config: ConfigFile = ConfigFile.new()
	for action: String in section_values:
		config.set_value("bindings", action, section_values[action])
	config.save(PATH)


func test_movement_defaults_are_physical_wasd() -> void:
	var expected: Dictionary = {&"move_forward": KEY_W, &"move_left": KEY_A, &"move_back": KEY_S, &"move_right": KEY_D}
	for action: StringName in expected:
		var key: InputEventKey = _settings.get_binding(action)[0] as InputEventKey
		assert_eq(key.physical_keycode, expected[action], "%s uses the key position" % action)
		assert_eq(key.keycode, KEY_NONE, "%s does not use the letter, so AZERTY gets ZQSD" % action)


func test_rebind_survives_reload_and_saves_physical_key() -> void:
	assert_true(_settings.set_binding(&"reload", 0, _key(KEY_T)))
	_settings.set_binding(&"fire", 1, _mouse(MOUSE_BUTTON_XBUTTON1))
	var config: ConfigFile = ConfigFile.new()
	config.load(PATH)
	assert_eq(config.get_value("bindings", "reload"), [{"type": "key", "physical": KEY_T}])
	assert_false(config.has_section_key("bindings", "jump"), "unchanged actions are not written")
	_settings._reset_all_bindings()
	var reloaded: Node = _new_settings()
	assert_eq(reloaded.get_binding(&"reload").size(), 1)
	assert_eq((reloaded.get_binding(&"reload")[0] as InputEventKey).physical_keycode, KEY_T)
	assert_eq(_codes(&"fire"), [-MOUSE_BUTTON_LEFT, -MOUSE_BUTTON_XBUTTON1], "backup slot survives too")


func test_binding_owner_catches_a_key_used_by_two_actions() -> void:
	assert_eq(_settings.binding_owner(_key(KEY_R)), &"reload")
	assert_eq(_settings.binding_owner(_key(KEY_R), &"reload"), &"", "the action itself does not count")
	assert_eq(_settings.binding_owner(_key(KEY_K)), &"", "a free key has no owner")
	_settings.set_binding(&"jump", 0, _key(KEY_R))
	assert_eq(_settings.binding_owner(_key(KEY_R), &"jump"), &"reload", "the duplicate is found")


func test_swap_gives_the_other_action_the_old_key() -> void:
	assert_true(_settings.swap_binding(&"reload", 0, _key(KEY_SPACE)))
	assert_eq(_codes(&"reload"), [KEY_SPACE])
	assert_eq(_codes(&"jump"), [KEY_R], "jump gets reload's old key")
	_settings.swap_binding(&"reload", 1, _key(KEY_R))
	assert_eq(_codes(&"reload"), [KEY_SPACE, KEY_R])
	assert_eq(_codes(&"jump"), [], "an empty slot leaves the other action unbound, as the player chose")


func test_same_key_twice_in_one_action_keeps_one() -> void:
	_settings.set_binding(&"reload", 1, _key(KEY_R))
	assert_eq(_codes(&"reload"), [KEY_R])


func test_reset_one_action_and_reset_all() -> void:
	_settings.set_binding(&"reload", 0, _key(KEY_T))
	_settings.set_binding(&"jump", 0, _key(KEY_J))
	_settings.reset_binding(&"reload")
	assert_eq(_codes(&"reload"), [KEY_R])
	assert_eq(_codes(&"jump"), [KEY_J])
	_settings.reset_to_defaults()
	assert_eq(_codes(&"jump"), [KEY_SPACE])
	var config: ConfigFile = ConfigFile.new()
	config.load(PATH)
	assert_false(config.has_section("bindings"), "defaults leave nothing to save")


func test_pause_escape_and_controller_cannot_be_bound() -> void:
	assert_false(_settings.set_binding(&"pause", 0, _key(KEY_P)), "pause is locked")
	assert_false(_settings.set_binding(&"jump", 0, _key(KEY_ESCAPE)), "Esc is never bound")
	assert_false(_settings.set_binding(&"jump", 0, InputEventJoypadButton.new()))
	assert_false(_settings.set_binding(&"jump", 2, _key(KEY_J)), "only main and backup slots")
	assert_false(&"pause" in _settings.rebindable_actions())
	assert_true(&"jump" in _settings.rebindable_actions())


func test_controller_events_survive_a_rebind() -> void:
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	InputMap.action_add_event(&"jump", pad)
	_settings.set_binding(&"jump", 0, _key(KEY_J))
	assert_true(InputMap.action_has_event(&"jump", pad))
	InputMap.action_erase_event(&"jump", pad)


func test_bad_saved_bindings_fall_back_to_defaults() -> void:
	_write_config(
		{
			"reload": [{"type": "key", "physical": KEY_T}],
			"jump": "space",
			"fire": [{"type": "key"}],
			"crouch": [{"type": "key", "physical": KEY_ESCAPE}],
			"sprint": [{"type": "key", "physical": KEY_1}, {"type": "key", "physical": KEY_2}, {"type": "key"}],
			"not_an_action": [{"type": "key", "physical": KEY_K}],
			"pause": [{"type": "key", "physical": KEY_P}],
		}
	)
	_settings.load_settings()
	assert_eq(_codes(&"reload"), [KEY_T], "good entries still load")
	assert_eq(_codes(&"jump"), [KEY_SPACE])
	assert_eq(_codes(&"fire"), [-MOUSE_BUTTON_LEFT])
	assert_eq(_codes(&"crouch"), [KEY_CTRL, KEY_C])
	assert_eq(_codes(&"sprint"), [KEY_SHIFT])
	assert_false(InputMap.has_action(&"not_an_action"))
	assert_eq(InputMap.action_get_events(&"pause").size(), 1)


func test_rebind_emits_changed_and_labels_name_the_key() -> void:
	watch_signals(_settings)
	_settings.set_binding(&"reload", 0, _key(KEY_T))
	assert_signal_emitted_with_parameters(_settings, "changed", [&"bindings", &"reload", null])
	assert_eq(_settings.event_label(_key(KEY_T)), "T")
	assert_eq(_settings.event_label(_key(KEY_SPACE)), "Space")
	assert_eq(_settings.event_label(_mouse(MOUSE_BUTTON_RIGHT)), "Right mouse")
	assert_eq(_settings.event_label(_mouse(MOUSE_BUTTON_XBUTTON2)), "Mouse 5")

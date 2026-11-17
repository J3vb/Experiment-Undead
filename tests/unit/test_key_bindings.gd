## Rebinding rows on the Controls tab: listen, Esc cancel, conflict Swap/Cancel and reset.
extends GutTest

const SCREEN: PackedScene = preload("res://systems/ui/settings_screen.tscn")
const PATH: String = "user://test_key_bindings.cfg"

var _screen: SettingsScreen
var _rows: KeyBindings
var _old_path: String


func before_each() -> void:
	_old_path = Settings.config_path
	Settings.config_path = PATH
	Settings._reset_all_bindings()
	_screen = SCREEN.instantiate() as SettingsScreen
	add_child_autofree(_screen)
	_rows = _screen.get_node("%KeyBindings") as KeyBindings


func after_each() -> void:
	Settings._reset_all_bindings()
	Settings.config_path = _old_path
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	return event


func _slot(action: StringName, slot: int) -> Button:
	return _rows.slots[action][slot] as Button


func _first_key(action: StringName) -> Key:
	return (Settings.get_binding(action)[0] as InputEventKey).physical_keycode


func test_every_rebindable_action_has_a_row_and_pause_has_none() -> void:
	assert_eq(_rows.slots.keys(), Settings.rebindable_actions())
	assert_false(_rows.slots.has(&"pause"), "pause stays locked")
	for action: StringName in _rows.slots:
		assert_false(KeyBindings.action_name(action).is_empty())
	assert_eq(_slot(&"move_forward", 0).text, "W")
	assert_eq(_slot(&"crouch", 1).text, "C", "the backup slot shows the second key")
	assert_eq(_slot(&"jump", 1).text, "Not set")
	assert_eq(_slot(&"fire", 0).text, "Left mouse")


func test_free_key_rebinds_and_saves() -> void:
	_slot(&"reload", 0).pressed.emit()
	assert_eq(_slot(&"reload", 0).text, "Press a key")
	_rows._input(_key(KEY_T))
	assert_eq(_first_key(&"reload"), KEY_T)
	assert_eq(_slot(&"reload", 0).text, "T")
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(PATH), OK, "the rebind is saved")
	assert_true(config.has_section_key("bindings", "reload"))


func test_mouse_button_rebinds() -> void:
	_slot(&"ads", 1).pressed.emit()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_XBUTTON1
	_rows._input(click)
	assert_eq(_slot(&"ads", 1).text, "Mouse 4")


func test_escape_cancels_the_rebind_and_does_not_close_settings() -> void:
	watch_signals(_screen)
	_slot(&"reload", 0).pressed.emit()
	var escape: InputEventKey = _key(KEY_ESCAPE)
	escape.keycode = KEY_ESCAPE
	_rows._input(escape)
	if not get_viewport().is_input_handled():
		_screen._input(escape)
	assert_true(_screen.visible, "Esc only cancels the rebind")
	assert_signal_not_emitted(_screen, "closed")
	assert_eq(_first_key(&"reload"), KEY_R)
	assert_eq(_slot(&"reload", 0).text, "R")


func test_taken_key_asks_and_swap_swaps() -> void:
	_slot(&"reload", 0).pressed.emit()
	_rows._input(_key(KEY_SPACE))
	assert_true(_rows.conflict.visible)
	assert_eq(_rows.conflict_label.text, "Space is used by Jump.")
	assert_eq(_first_key(&"reload"), KEY_R, "nothing changes before the player chooses")
	_rows.swap_button.pressed.emit()
	assert_eq(_first_key(&"reload"), KEY_SPACE)
	assert_eq(_first_key(&"jump"), KEY_R)
	assert_false(_rows.conflict.visible)


func test_taken_key_cancel_changes_nothing() -> void:
	_slot(&"reload", 0).pressed.emit()
	_rows._input(_key(KEY_SPACE))
	_rows.cancel_button.pressed.emit()
	assert_eq(_first_key(&"reload"), KEY_R)
	assert_eq(_first_key(&"jump"), KEY_SPACE)
	assert_eq(_slot(&"reload", 0).text, "R")


func test_reset_button_and_external_changes_update_the_rows() -> void:
	Settings.set_binding(&"jump", 0, _key(KEY_J))
	assert_eq(_slot(&"jump", 0).text, "J", "rows follow changes made elsewhere")
	var row: Node = _slot(&"jump", 0).get_parent()
	(row.get_child(row.get_child_count() - 1) as Button).pressed.emit()
	assert_eq(_first_key(&"jump"), KEY_SPACE)
	assert_eq(_slot(&"jump", 0).text, "Space")
	Settings.set_binding(&"jump", 0, _key(KEY_J))
	_screen.get_node("%Defaults").pressed.emit()
	assert_eq(_slot(&"jump", 0).text, "Space", "Defaults on the Controls page resets bindings")

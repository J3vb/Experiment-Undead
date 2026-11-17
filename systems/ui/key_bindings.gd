## Keyboard and mouse rebinding rows on the Controls tab: main and backup slot, reset, and swap on conflict.
class_name KeyBindings
extends VBoxContainer

const NAMES: Dictionary = {
	&"move_forward": "Move forward",
	&"move_back": "Move back",
	&"move_left": "Move left",
	&"move_right": "Move right",
	&"jump": "Jump",
	&"sprint": "Sprint",
	&"crouch": "Crouch",
	&"reload": "Reload",
	&"interact": "Interact, buy, repair",
	&"weapon_next": "Next weapon",
	&"weapon_prev": "Previous weapon",
	&"restart": "Restart after a run",
	&"fire": "Fire",
	&"alt_fire": "Alt fire",
	&"ads": "Aim down sights",
	&"pack_toggle": "Open Pack",
	&"pack_drop": "Drop from Pack",
	&"pack_equip": "Pack item into hands",
}
const SLOT_NAMES: Array[String] = ["Main", "Backup"]

var slots: Dictionary = {}
var status: Label
var conflict: HBoxContainer
var conflict_label: Label
var swap_button: Button
var cancel_button: Button

var _action: StringName = &""
var _slot: int = -1
var _pending: InputEvent


func _ready() -> void:
	var title: Label = Label.new()
	title.text = "Key bindings"
	add_child(title)
	status = Label.new()
	status.theme_type_variation = &"LabelDim"
	add_child(status)
	_build_conflict()
	for action: StringName in Settings.rebindable_actions():
		_build_row(action)
	Settings.changed.connect(_on_setting_changed)
	_stop()


func _build_conflict() -> void:
	conflict = HBoxContainer.new()
	conflict.add_theme_constant_override("separation", 16)
	add_child(conflict)
	conflict_label = Label.new()
	conflict.add_child(conflict_label)
	swap_button = Button.new()
	swap_button.text = "Swap"
	swap_button.pressed.connect(_swap)
	conflict.add_child(swap_button)
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_stop)
	conflict.add_child(cancel_button)


func _build_row(action: StringName) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var label: Label = Label.new()
	label.text = action_name(action)
	label.custom_minimum_size = Vector2(450, 40)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var buttons: Array[Button] = []
	for slot: int in SLOT_NAMES.size():
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(220, 40)
		button.tooltip_text = "%s key for %s" % [SLOT_NAMES[slot], label.text]
		button.pressed.connect(_listen.bind(action, slot))
		row.add_child(button)
		buttons.append(button)
	var reset: Button = Button.new()
	reset.text = "Reset"
	reset.pressed.connect(Settings.reset_binding.bind(action))
	row.add_child(reset)
	slots[action] = buttons


static func action_name(action: StringName) -> String:
	return NAMES.get(action, String(action).capitalize())


func _listen(action: StringName, slot: int) -> void:
	_stop()
	_action = action
	_slot = slot
	(slots[action][slot] as Button).text = "Press a key"
	status.text = "Press a key or mouse button for %s. Esc cancels." % action_name(action)


## Children get input before the settings screen, so Esc cancels the rebind instead of closing Settings.
func _input(event: InputEvent) -> void:
	if _action == &"" or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_stop()
		return
	var key: InputEventKey = event as InputEventKey
	if _pending or not event.is_pressed() or (key and key.echo):
		return
	if key == null and not event is InputEventMouseButton:
		return
	get_viewport().set_input_as_handled()
	var taken_by: StringName = Settings.binding_owner(event, _action)
	if taken_by == &"":
		Settings.set_binding(_action, _slot, event)
		_stop()
		return
	_pending = event
	conflict_label.text = "%s is used by %s." % [InputEvents.label(event), action_name(taken_by)]
	conflict.show()
	swap_button.grab_focus()


func _swap() -> void:
	if _pending:
		Settings.swap_binding(_action, _slot, _pending)
	_stop()


func _stop() -> void:
	var focus: Button = (slots[_action][_slot] as Button) if _action != &"" else null
	_action = &""
	_slot = -1
	_pending = null
	conflict.hide()
	status.text = "Select a key to change it. Each key does one thing."
	_refresh()
	if focus:
		focus.grab_focus()


func _on_setting_changed(_section: StringName, _key: StringName, _value: Variant) -> void:
	if _action == &"":
		_refresh()


func _refresh() -> void:
	for action: StringName in slots:
		var events: Array[InputEvent] = Settings.get_binding(action)
		var buttons: Array[Button] = slots[action]
		for slot: int in buttons.size():
			buttons[slot].text = InputEvents.label(events[slot]) if slot < events.size() else "Not set"

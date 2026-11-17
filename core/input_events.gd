## Plain keyboard and mouse events for bindings: clean copies, comparison, save format and the label to show.
class_name InputEvents

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


## What to show for a key or button: the letter on the player's own keyboard layout.
static func label(event: InputEvent) -> String:
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


static func from_value(value: Variant) -> InputEvent:
	var entry: Dictionary = value if value is Dictionary else {}
	if entry.get("type") == "key" and entry.get("physical") is int:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = entry["physical"]
		return clean(key)
	if entry.get("type") == "mouse" and entry.get("button") is int:
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = entry["button"]
		return clean(button)
	return null


static func to_value(event: InputEvent) -> Dictionary:
	var key: InputEventKey = event as InputEventKey
	if key:
		return {"type": "key", "physical": int(key.physical_keycode)}
	return {"type": "mouse", "button": int((event as InputEventMouseButton).button_index)}


## A plain physical key or mouse button with no modifiers, or null if it cannot be bound (Esc, controller).
static func clean(event: InputEvent) -> InputEvent:
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


static func same(a: InputEvent, b: InputEvent) -> bool:
	var clean_a: InputEvent = clean(a)
	var clean_b: InputEvent = clean(b)
	if clean_a == null or clean_b == null:
		return false
	return to_value(clean_a) == to_value(clean_b)


static func same_list(a: Array[InputEvent], b: Array[InputEvent]) -> bool:
	if a.size() != b.size():
		return false
	for index: int in a.size():
		if not same(a[index], b[index]):
			return false
	return true

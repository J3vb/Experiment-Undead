# Writes the default input map into project.godot.
# Run: godot --headless --path . --script res://tools/setup_input.gd
# Uses physical keys, so WASD sits in the same place on AZERTY keyboards.
extends SceneTree

const KEYS: Dictionary = {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"reload": [KEY_R],
	"interact": [KEY_F],
	"pause": [KEY_ESCAPE],
	"weapon_next": [KEY_Q],
	"restart": [KEY_ENTER],
}
const MOUSE: Dictionary = {
	"fire": [MOUSE_BUTTON_LEFT],
	"ads": [MOUSE_BUTTON_RIGHT],
	"weapon_prev": [MOUSE_BUTTON_WHEEL_UP],
}

func _initialize() -> void:
	for action: String in KEYS:
		var events: Array = []
		for key: Key in KEYS[action]:
			var e: InputEventKey = InputEventKey.new()
			e.physical_keycode = key
			events.append(e)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	for action: String in MOUSE:
		var events: Array = []
		for button: MouseButton in MOUSE[action]:
			var e: InputEventMouseButton = InputEventMouseButton.new()
			e.button_index = button
			events.append(e)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	var err: Error = ProjectSettings.save()
	print("Input map saved: ", error_string(err))
	quit()

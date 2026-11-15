## Alternate fire keeps its mouse/controller defaults and enters the input frame.
extends GutTest

var local_input: LocalInput
var _was_pressed: bool = false


func before_each() -> void:
	local_input = LocalInput.new()
	add_child_autofree(local_input)
	_was_pressed = local_input.sample(0).has(InputFrame.ALT_FIRE)
	Input.action_release(&"alt_fire")


func after_each() -> void:
	Input.action_release(&"alt_fire")
	if _was_pressed:
		Input.action_press(&"alt_fire")


func test_alt_fire_defaults_to_middle_mouse_and_right_stick_click() -> void:
	assert_true(InputMap.has_action(&"alt_fire"))
	var middle_mouse: bool = false
	var right_stick: bool = false
	for event: InputEvent in InputMap.action_get_events(&"alt_fire"):
		if event is InputEventMouseButton:
			middle_mouse = middle_mouse or (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE
		elif event is InputEventJoypadButton:
			right_stick = right_stick or (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_STICK
	assert_true(middle_mouse, "default mouse binding is the middle button")
	assert_true(right_stick, "default controller binding is R3")


func test_local_input_samples_held_and_released_alt_fire() -> void:
	assert_false(local_input.sample(40).has(InputFrame.ALT_FIRE))
	Input.action_press(&"alt_fire")
	var frame: InputFrame = local_input.sample(41)
	assert_eq(frame.tick, 41)
	assert_true(frame.has(InputFrame.ALT_FIRE))
	assert_eq(frame.buttons & InputFrame.FIRE, 0, "alt has its own input bit")
	assert_true(local_input.sample(42).has(InputFrame.ALT_FIRE), "held input survives the next sample")
	Input.action_release(&"alt_fire")
	assert_false(local_input.sample(43).has(InputFrame.ALT_FIRE))


func test_disabled_local_input_never_emits_alt_fire() -> void:
	Input.action_press(&"alt_fire")
	local_input.enabled = false
	var frame: InputFrame = local_input.sample(51)
	assert_eq(frame.tick, 51)
	assert_false(frame.has(InputFrame.ALT_FIRE))
	assert_eq(frame.buttons, 0)
	local_input.enabled = true
	assert_true(local_input.sample(52).has(InputFrame.ALT_FIRE), "reenabling resumes current input")

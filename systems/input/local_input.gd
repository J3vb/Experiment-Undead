## Turns this machine's keyboard and mouse into InputFrames for one player.
## Mouse movement is gathered between ticks and handed over once per tick.
class_name LocalInput
extends Node

@export var mouse_sensitivity: float = 0.0022

var enabled: bool = true
## Set by the owner each tick; scales look while aiming.
var sensitivity_scale: float = 1.0

var _look_accum: Vector2 = Vector2.ZERO
var _pressed: int = 0

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_accum += motion.relative
	elif event.is_action_pressed(&"weapon_next"):
		_pressed |= InputFrame.NEXT_WEAPON
	elif event.is_action_pressed(&"weapon_prev"):
		_pressed |= InputFrame.PREV_WEAPON

## Builds the frame for this tick and clears the accumulators.
func sample(tick: int) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.tick = tick
	if not enabled:
		_look_accum = Vector2.ZERO
		_pressed = 0
		return f
	f.move = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	f.look = _look_accum * mouse_sensitivity * sensitivity_scale
	_look_accum = Vector2.ZERO
	var b: int = _pressed
	_pressed = 0
	if Input.is_action_pressed(&"fire"): b |= InputFrame.FIRE
	if Input.is_action_pressed(&"ads"): b |= InputFrame.ADS
	if Input.is_action_pressed(&"sprint"): b |= InputFrame.SPRINT
	if Input.is_action_pressed(&"crouch"): b |= InputFrame.CROUCH
	if Input.is_action_just_pressed(&"jump"): b |= InputFrame.JUMP
	if Input.is_action_just_pressed(&"reload"): b |= InputFrame.RELOAD
	if Input.is_action_just_pressed(&"interact"): b |= InputFrame.INTERACT
	f.buttons = b
	return f

## Turns this machine's keyboard and mouse into InputFrames for one player.
## Mouse movement is gathered between ticks and handed over once per tick.
class_name LocalInput
extends Node

## Actions read as one-tick presses from input events.
const PRESS_BITS: Dictionary[StringName, int] = {
	&"weapon_next": InputFrame.NEXT_WEAPON,
	&"weapon_prev": InputFrame.PREV_WEAPON,
	&"weapon_slot_1": InputFrame.SLOT_1,
	&"weapon_slot_2": InputFrame.SLOT_2,
	&"weapon_slot_3": InputFrame.SLOT_3,
	&"melee": InputFrame.MELEE,
}

var mouse_sensitivity: float = 0.0022
var invert_y: bool = false
## Look scale at full aim, from the ADS sensitivity setting.
var ads_multiplier: float = 0.8

var enabled: bool = true
## Set by the owner each tick; scales look while aiming.
var sensitivity_scale: float = 1.0

var _look_accum: Vector2 = Vector2.ZERO
var _pressed: int = 0
var _crouch_on: bool = false


func _ready() -> void:
	_update_controls()
	Settings.changed.connect(_on_settings_changed)


func _update_controls() -> void:
	mouse_sensitivity = Settings.get_value(&"aim", &"mouse_sensitivity")
	invert_y = Settings.get_value(&"aim", &"invert_y")
	ads_multiplier = Settings.get_value(&"aim", &"ads_sensitivity_multiplier")


func _on_settings_changed(section: StringName, _key: StringName, _value: Variant) -> void:
	if section == &"aim":
		_update_controls()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_accum += motion.relative
		return
	for action: StringName in PRESS_BITS:
		if event.is_action_pressed(action):
			_pressed |= PRESS_BITS[action]
	if event.is_action_pressed(&"crouch"):
		_crouch_on = not _crouch_on
	elif event.is_action_pressed(&"sprint") or event.is_action_pressed(&"jump"):
		_crouch_on = false


## Builds the frame for this tick and clears the accumulators.
func sample(tick: int) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.tick = tick
	if not enabled or UI.top() != &"":
		_look_accum = Vector2.ZERO
		_pressed = 0
		_crouch_on = false
		return f
	f.move = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	f.look = _look_accum * mouse_sensitivity * sensitivity_scale
	if invert_y:
		f.look.y = -f.look.y
	_look_accum = Vector2.ZERO
	var b: int = _pressed | _held_buttons()
	_pressed = 0
	if Input.is_action_just_pressed(&"jump"):
		b |= InputFrame.JUMP
	if Input.is_action_just_pressed(&"reload"):
		b |= InputFrame.RELOAD
	if Input.is_action_just_pressed(&"interact"):
		b |= InputFrame.INTERACT
	f.buttons = b
	return f


func _held_buttons() -> int:
	var b: int = 0
	if Input.is_action_pressed(&"alt_fire"):
		b |= InputFrame.ALT_FIRE
	if Input.is_action_pressed(&"fire"):
		b |= InputFrame.FIRE
	if Input.is_action_pressed(&"ads"):
		b |= InputFrame.ADS
	if Input.is_action_pressed(&"sprint"):
		b |= InputFrame.SPRINT
	if _crouch_on:  # Crouch is a toggle: a press flips it, a sprint or jump press stands up.
		b |= InputFrame.CROUCH
	return b

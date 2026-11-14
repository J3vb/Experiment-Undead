## One physics tick of player intent. The player controller only ever reads
## these, so the same code can run from keyboard, network or a replay.
class_name InputFrame
extends RefCounted

const FIRE: int = 1 << 0
const ADS: int = 1 << 1
const SPRINT: int = 1 << 2
const CROUCH: int = 1 << 3
const JUMP: int = 1 << 4 ## Pressed this tick.
const RELOAD: int = 1 << 5 ## Pressed this tick.
const NEXT_WEAPON: int = 1 << 6 ## Pressed this tick.
const PREV_WEAPON: int = 1 << 7 ## Pressed this tick.
const INTERACT: int = 1 << 8 ## Pressed this tick.

var tick: int = 0
var move: Vector2 = Vector2.ZERO
## Look change in radians this tick (x = yaw, y = pitch, mouse-style signs).
var look: Vector2 = Vector2.ZERO
var buttons: int = 0

func has(flag: int) -> bool:
	return buttons & flag != 0

func to_dict() -> Dictionary:
	return {"t": tick, "m": move, "l": look, "b": buttons}

static func from_dict(d: Dictionary) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.tick = d.get("t", 0)
	f.move = d.get("m", Vector2.ZERO)
	f.look = d.get("l", Vector2.ZERO)
	f.buttons = d.get("b", 0)
	return f

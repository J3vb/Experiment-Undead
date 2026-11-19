## One physics tick of player intent. The player controller only ever reads
## these, so the same code can run from keyboard, network or a replay.
class_name InputFrame
extends RefCounted

const FIRE: int = 1 << 0
const ADS: int = 1 << 1
const SPRINT: int = 1 << 2
const CROUCH: int = 1 << 3
const JUMP: int = 1 << 4  ## Pressed this tick.
const RELOAD: int = 1 << 5  ## Pressed this tick.
const NEXT_WEAPON: int = 1 << 6  ## Pressed this tick.
const PREV_WEAPON: int = 1 << 7  ## Pressed this tick.
const INTERACT: int = 1 << 8  ## Pressed this tick.
const ALT_FIRE: int = 1 << 9
const SLOT_1: int = 1 << 10  ## Pressed this tick; SLOT_2 and SLOT_3 follow.
const SLOT_2: int = 1 << 11
const SLOT_3: int = 1 << 12
const SLOTS: Array[int] = [SLOT_1, SLOT_2, SLOT_3]
const MELEE: int = 1 << 13  ## Pressed this tick.
const INTERACT_HELD: int = 1 << 14  ## Held down; INTERACT is the press.

var tick: int = 0
var move: Vector2 = Vector2.ZERO
## Look change in radians this tick (x = yaw, y = pitch, mouse-style signs).
var look: Vector2 = Vector2.ZERO
var buttons: int = 0


func has(flag: int) -> bool:
	return buttons & flag != 0

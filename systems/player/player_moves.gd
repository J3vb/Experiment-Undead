## Slide and jump rules for one Player: a crouch press during a floor sprint
## slides 0.8 s from 8 m/s down to crouch speed; chained jumps lose height.
class_name PlayerMoves
extends RefCounted

const SLIDE_TIME: float = 0.8
const SLIDE_SPEED: float = 8.0
## Jumps within this many seconds of landing are chained.
const CHAIN_WINDOW: float = 0.4
## Each chained jump reaches this share of the last one's height.
const CHAIN_HEIGHT: float = 0.8

var slide_left: float = 0.0
var _slide_time: float = SLIDE_TIME
var _slide_dir: Vector3 = Vector3.FORWARD
var _crouch_was: bool = false
var _jump_height: float = 1.0
var _floor_time: float = CHAIN_WINDOW


func is_sliding() -> bool:
	return slide_left > 0.0


## Starts a slide on the tick crouch is pressed during a floor sprint.
## Standing up (crouch off) ends it. True while sliding.
func update_slide(player: Player, frame: InputFrame) -> bool:
	var crouch: bool = frame.has(InputFrame.CROUCH)
	if crouch and not _crouch_was and player.is_sprinting and player.is_on_floor():
		_slide_time = SLIDE_TIME * player.get_stat(&"slide_time")
		slide_left = _slide_time
		var flat: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
		_slide_dir = flat.normalized() if flat.length_squared() > 0.01 else -player.global_basis.z
	_crouch_was = crouch
	if not crouch or player.is_downed:
		slide_left = 0.0
	return is_sliding()


## Horizontal velocity for one slide tick: steering is locked and the speed
## falls evenly from SLIDE_SPEED to end_speed (the crouch speed).
func slide_step(delta: float, end_speed: float) -> Vector3:
	slide_left = maxf(slide_left - delta, 0.0)
	var t: float = 1.0 - slide_left / maxf(_slide_time, 0.001)
	return _slide_dir * lerpf(SLIDE_SPEED, end_speed, t)


## Vertical velocity after gravity and an optional jump. A jump within
## CHAIN_WINDOW of landing reaches CHAIN_HEIGHT of the previous jump's height.
func vertical(player: Player, delta: float, wants_jump: bool, gravity: float) -> float:
	if not player.is_on_floor():
		_floor_time = 0.0
		return player.velocity.y - gravity * delta
	_floor_time += delta
	if _floor_time >= CHAIN_WINDOW:
		_jump_height = 1.0
	if not wants_jump:
		return player.velocity.y
	var speed: float = player.jump_velocity * sqrt(_jump_height)
	_jump_height *= CHAIN_HEIGHT
	return speed

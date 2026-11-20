## Spring pendulum for a charm hanging from a gun: tilts against the mount's acceleration, then settles.
class_name CharmSwing
extends RefCounted

const STIFFNESS: float = 60.0
const DAMPING: float = 7.0
const MAX_ANGLE: float = 0.7
const GRAVITY: float = 9.8

var angle: Vector2 = Vector2.ZERO
var _speed: Vector2 = Vector2.ZERO
var _last_origin: Vector3 = Vector3.ZERO
var _last_velocity: Vector3 = Vector3.ZERO
var _frames: int = 0


## Advances the swing for a mount at `mount` and returns the charm's tilt in mount space.
func step(mount: Transform3D, delta: float) -> Basis:
	if delta <= 0.0:
		return Basis.from_euler(Vector3(angle.x, 0.0, angle.y))
	var velocity: Vector3 = (mount.origin - _last_origin) / delta if _frames > 0 else Vector3.ZERO
	var accel: Vector3 = (velocity - _last_velocity) / delta if _frames > 1 else Vector3.ZERO
	_last_origin = mount.origin
	_last_velocity = velocity
	_frames = mini(_frames + 1, 2)
	var local: Vector3 = mount.basis.inverse() * accel
	var target: Vector2 = (Vector2(local.z, -local.x) / GRAVITY).clampf(-MAX_ANGLE, MAX_ANGLE)
	_speed += ((target - angle) * STIFFNESS - _speed * DAMPING) * delta
	angle = (angle + _speed * delta).clampf(-MAX_ANGLE, MAX_ANGLE)
	return Basis.from_euler(Vector3(angle.x, 0.0, angle.y))


## Forgets motion, e.g. after a weapon switch moves the mount in one frame.
func reset() -> void:
	_frames = 0
	_speed = Vector2.ZERO
	angle = Vector2.ZERO

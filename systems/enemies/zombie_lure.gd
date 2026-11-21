## Decoy Siren pull on one chasing zombie (plans/field-abilities.md step 5): for a few seconds it
## walks to the siren over the navmesh instead of chasing, and never swings. Zombies at a window
## keep tearing planks; the lure only takes over the chase. Server only; positions sync.
class_name ZombieLure
extends RefCounted

## Close enough to the siren to stand and listen.
const ARRIVED: float = 1.5
const REPATH: float = 0.5

var point: Vector3 = Vector3.ZERO
var left: float = 0.0
var _repath: float = 0.0


func start(at: Vector3, seconds: float) -> void:
	point = at
	left = maxf(left, seconds)
	_repath = 0.0


func is_active() -> bool:
	return left > 0.0


## Called at the start of each chase tick. True when the lure moved the zombie this tick.
func tick(zombie: Zombie, delta: float) -> bool:
	if left <= 0.0:
		return false
	left = maxf(left - delta, 0.0)
	if left == 0.0:
		zombie.restart_chase()
		return false
	_repath -= delta
	if _repath <= 0.0:
		_repath = REPATH
		zombie.agent.target_position = point
	var to_point: Vector3 = point - zombie.global_position
	to_point.y = 0.0
	var direction: Vector3 = zombie.agent.get_next_path_position() - zombie.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01 or zombie.agent.is_navigation_finished():
		direction = to_point
	direction = direction.normalized() if to_point.length() > ARRIVED else Vector3.ZERO
	zombie._steer(direction * zombie._speed + zombie._separation(), delta)
	zombie._face(to_point, delta)
	return true

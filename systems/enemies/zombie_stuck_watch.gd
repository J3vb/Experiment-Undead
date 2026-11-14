## Early warning for navmesh holes, bad spawn points and zombies wedged in
## geometry: a chasing zombie that moves less than STUCK_DISTANCE in
## STUCK_TIME seconds while out of reach is reported to the Log once.
## Logs only; the zombie keeps trying.
class_name ZombieStuckWatch
extends RefCounted

const STUCK_TIME: float = 3.0
const STUCK_DISTANCE: float = 0.3
const FELL_OUT_Y: float = -50.0

var _timer: float = 0.0
var _from: Vector3 = Vector3.ZERO
var _reported: bool = false


## Call when the zombie starts chasing.
func restart(at: Vector3) -> void:
	_timer = 0.0
	_from = at


func tick(zombie: Zombie, delta: float, distance: float) -> void:
	_timer += delta
	if _timer < STUCK_TIME or _reported:
		return
	_timer = 0.0
	var at: Vector3 = zombie.global_position
	var moved: float = at.distance_to(_from)
	_from = at
	var fell: bool = at.y < FELL_OUT_Y
	if fell or (moved < STUCK_DISTANCE and distance > zombie.data.attack_range):
		_reported = true
		var data_out: Dictionary = {
			"net_id": zombie.net_id,
			"enemy": zombie.data.resource_path.get_file().get_basename(),
			"at": str(at.snappedf(0.1)),
			"target_distance": snappedf(distance, 0.1),
			"next_path_point": str(zombie.agent.get_next_path_position().snappedf(0.1)),
			"path_finished": zombie.agent.is_navigation_finished(),
		}
		Log.warn(&"enemies", &"zombie_fell_out" if fell else &"zombie_stuck", data_out)

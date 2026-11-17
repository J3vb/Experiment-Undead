## Watches a chasing zombie and fixes it when it gets lost: every WINDOW
## seconds without STUCK_DISTANCE of progress (outside attack reach) adds to an
## unreachable timer, whether or not its path is finished. After RELOCATE_TIME
## unreachable, FAR_TIME over FAR_DISTANCE from every player, or a fall out of
## the map, the Spawner moves it to a hidden spawn (zombie-ai.md#stuck-handling).
class_name ZombieStuckWatch
extends RefCounted

const STUCK_TIME: float = 2.0
const STUCK_DISTANCE: float = 0.3
const FELL_OUT_Y: float = -50.0
const RELOCATE_TIME: float = 20.0
const FAR_DISTANCE: float = 60.0
const FAR_TIME: float = 15.0
## Wait between relocate tries when no hidden spawn is free.
const RETRY_TIME: float = 1.0

var unreachable_time: float = 0.0
var far_time: float = 0.0

var _timer: float = 0.0
var _retry: float = 0.0
var _from: Vector3 = Vector3.ZERO
var _reported: bool = false


## Call when the zombie starts chasing.
func restart(at: Vector3) -> void:
	_timer = 0.0
	_from = at
	unreachable_time = 0.0
	far_time = 0.0


func tick(zombie: Zombie, delta: float, distance: float) -> void:
	_timer += delta
	_retry = maxf(_retry - delta, 0.0)
	far_time = far_time + delta if distance > FAR_DISTANCE else 0.0
	var at: Vector3 = zombie.global_position
	if _timer >= STUCK_TIME:
		_timer = 0.0
		var moved: float = at.distance_to(_from)
		_from = at
		if moved < STUCK_DISTANCE and distance > zombie.data.attack_range:
			unreachable_time += STUCK_TIME
			if not _reported:
				_reported = true
				_report(zombie, distance, &"zombie_stuck")
		else:
			unreachable_time = 0.0
	var reason: StringName = _relocate_reason(at.y)
	if reason == &"fell_out" and _retry <= 0.0:
		_report(zombie, distance, &"zombie_fell_out")
	if reason != &"" and _retry <= 0.0 and Net.is_authority():
		var spawner: Spawner = zombie.get_parent() as Spawner
		if spawner and spawner.relocate(zombie, reason):
			restart(zombie.global_position)
		else:
			_retry = RETRY_TIME


func _relocate_reason(y: float) -> StringName:
	if y < FELL_OUT_Y:
		return &"fell_out"
	if unreachable_time >= RELOCATE_TIME:
		return &"unreachable"
	if far_time >= FAR_TIME:
		return &"far"
	return &""


func _report(zombie: Zombie, distance: float, event: StringName) -> void:
	var at: Vector3 = zombie.global_position
	var data_out: Dictionary = {
		"net_id": zombie.net_id,
		"enemy": zombie.data.resource_path.get_file().get_basename(),
		"at": str(at.snappedf(0.1)),
		"target_distance": snappedf(distance, 0.1),
		"next_path_point": str(zombie.agent.get_next_path_position().snappedf(0.1)),
		"path_finished": zombie.agent.is_navigation_finished(),
	}
	Log.warn(&"enemies", event, data_out)

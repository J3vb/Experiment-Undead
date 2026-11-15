## The only place enemies are created. Picks a spawn point away from
## players, assigns a network id and scales stats for the round.
class_name Spawner
extends Node3D

@export var spawn_group: StringName = &"enemy_spawn"

var session: GameSession


func spawn(enemy: EnemyData, round_number: int, rules: WaveRules) -> Zombie:
	if not Net.is_authority() or enemy == null or enemy.scene == null:
		return null
	var marker: Node3D = _pick_marker(rules.min_spawn_distance)
	var point: Vector3 = _place(marker)
	var zombie: Zombie = enemy.scene.instantiate() as Zombie
	zombie.setup(
		enemy,
		Net.allocate_id(),
		rules.get_health_multiplier(round_number),
		rules.get_speed_multiplier(round_number),
		rules.get_damage_multiplier(round_number),
		session.rng
	)
	var spawn_point: ZombieSpawnPoint = marker as ZombieSpawnPoint
	if spawn_point:
		zombie.barrier = spawn_point.barrier
	add_child(zombie)
	zombie.global_position = point
	zombie.rotation.y = session.rng.randf() * TAU
	Events.enemy_spawned.emit(zombie)
	return zombie


func alive_count() -> int:
	var n: int = 0
	for child: Node in get_children():
		var z: Zombie = child as Zombie
		if z and z.state != Zombie.State.DEAD:
			n += 1
	return n


func _pick_marker(min_distance: float) -> Node3D:
	var points: Array[Node] = get_tree().get_nodes_in_group(spawn_group)
	if points.is_empty():
		Log.warn(&"waves", &"spawn_points_missing", {"spawn_group": spawn_group})
		return null
	var far_enough: Array[Node3D] = []
	for node: Node in points:
		var marker: Node3D = node as Node3D
		if marker and _distance_to_nearest_player(marker.global_position) >= min_distance:
			far_enough.append(marker)
	var pool: Array = points
	if not far_enough.is_empty():
		pool = far_enough
	return pool[session.rng.randi_range(0, pool.size() - 1)] as Node3D


func _place(chosen: Node3D) -> Vector3:
	if chosen == null:
		return global_position
	var jitter: Vector3 = Vector3(session.rng.randf_range(-1.0, 1.0), 0.0, session.rng.randf_range(-1.0, 1.0))
	var wanted: Vector3 = chosen.global_position + jitter
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		return NavigationServer3D.map_get_closest_point(map, wanted)
	return wanted


func _distance_to_nearest_player(at: Vector3) -> float:
	var best: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		best = minf(best, at.distance_to((node as Node3D).global_position))
	return best

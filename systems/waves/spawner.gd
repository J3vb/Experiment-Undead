## The only place enemies are created. Picks a spawn point away from
## players, assigns a network id and scales stats for the round.
class_name Spawner
extends Node3D

@export var spawn_group: StringName = &"enemy_spawn"

var session: GameSession
## Live zombies made here, on this peer. Each zombie shares this array as its neighbours.
var zombies: Array[Zombie] = []

var _net: MultiplayerSpawner


func _ready() -> void:
	_net = MultiplayerSpawner.new()
	_net.name = "Net"
	_net.spawn_function = _create
	add_child(_net)
	_net.spawn_path = _net.get_path_to(self)
	_net.spawned.connect(func(node: Node) -> void: Events.enemy_spawned.emit(node as Zombie))


func spawn(enemy: EnemyData, round_number: int, rules: WaveRules) -> Zombie:
	if not Net.is_authority() or enemy == null or enemy.scene == null:
		return null
	var marker: Node3D = _pick_marker(rules.min_spawn_distance)
	var point: Vector3 = _place(marker)
	var spawn_point: ZombieSpawnPoint = marker as ZombieSpawnPoint
	var barrier_path: NodePath = get_path_to(spawn_point.barrier) if spawn_point and spawn_point.barrier else ^""
	var data: Array = [
		enemy.resource_path,
		Net.allocate_id(),
		rules.get_health_multiplier(round_number),
		rules.get_speed_multiplier(round_number),
		rules.get_damage_multiplier(round_number),
		barrier_path,
		to_local(point),
	]
	var zombie: Zombie = _net.spawn(data) as Zombie
	zombie.rotation.y = session.rng.randf() * TAU
	Events.enemy_spawned.emit(zombie)
	return zombie


## Runs on the server and on every client with the same data.
func _create(data: Array) -> Node:
	var enemy: EnemyData = load(data[0]) as EnemyData
	var zombie: Zombie = enemy.scene.instantiate() as Zombie
	var rng: RandomNumberGenerator = session.rng if Net.is_authority() else RandomNumberGenerator.new()
	zombie.setup(enemy, data[1], data[2], data[3], data[4], rng)
	zombie.name = "Zombie%d" % zombie.net_id
	zombie.position = data[6]
	if not (data[5] as NodePath).is_empty():
		zombie.barrier = get_node(data[5]) as Barrier
	zombie.add_child(ZombieSync.new())
	zombie.neighbours = zombies
	zombies.append(zombie)
	zombie.tree_exiting.connect(func() -> void: zombies.erase(zombie))
	return zombie


func alive_count() -> int:
	var n: int = 0
	for zombie: Zombie in zombies:
		if zombie.state != Zombie.State.DEAD:
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

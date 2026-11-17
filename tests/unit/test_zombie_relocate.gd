## Lost zombies relocate to a hidden spawn, keep their health and chase again;
## the round's last zombies hurry (docs/plans/core-loop-gaps.md, step 2).
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WALKER: String = "res://content/enemies/zombie_walker.tres"
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")

var spawner: Spawner
var points: Array[ZombieSpawnPoint] = []


func before_each() -> void:
	spawner = Spawner.new()
	spawner.spawn_group = &"test_relocate_points"
	spawner.session = GameSession.new()
	autofree(spawner.session)
	add_child_autofree(spawner)
	points.clear()


func _point(at: Vector3) -> ZombieSpawnPoint:
	var point: ZombieSpawnPoint = ZombieSpawnPoint.new()
	point.name = "Point%d" % points.size()
	add_child_autofree(point)
	point.global_position = at
	point.add_to_group(spawner.spawn_group)
	points.append(point)
	return point


func _zombie(at: Vector3) -> Zombie:
	var data: Array = [WALKER, Net.allocate_id(), 1.0, 1.0, 1.0, ^"", at]
	var zombie: Zombie = spawner._create(data) as Zombie
	spawner.add_child(zombie)
	zombie.set_physics_process(false)
	zombie.state = Zombie.State.CHASING
	zombie._stuck_watch.restart(zombie.global_position)
	return zombie


func _relocations() -> int:
	return Log.event_counts.get("enemies.zombie_relocated", 0)


func _tick(zombie: Zombie, seconds: float, distance: float, move_per_tick: float = 0.0) -> void:
	for i: int in roundi(seconds * 10.0):
		zombie.global_position.x += move_per_tick
		zombie._stuck_watch.tick(zombie, 0.1, distance)


func test_unreachable_zombie_relocates_after_20_seconds_and_keeps_health() -> void:
	_point(Vector3(40, 0, 0))
	var zombie: Zombie = _zombie(Vector3.ZERO)
	zombie.health.current = 55.0
	var before: int = _relocations()
	_tick(zombie, 19.0, 8.0)
	assert_eq(_relocations(), before, "still waiting at 19 s")
	_tick(zombie, 1.5, 8.0)
	assert_eq(_relocations(), before + 1, "moved to the hidden spawn")
	assert_eq(zombie.health.current, 55.0, "health kept")
	assert_eq(zombie.state, Zombie.State.CHASING)
	assert_eq(zombie._stuck_watch.unreachable_time, 0.0, "timers restart after the move")


func test_finished_path_but_blocked_still_counts() -> void:
	_point(Vector3(40, 0, 0))
	var zombie: Zombie = _zombie(Vector3.ZERO)
	zombie.agent.target_position = zombie.global_position
	var before: int = _relocations()
	_tick(zombie, 20.5, 5.0)
	assert_eq(_relocations(), before + 1, "relocated even with a finished path")


func test_moving_zombie_never_relocates() -> void:
	_point(Vector3(40, 0, 0))
	var zombie: Zombie = _zombie(Vector3.ZERO)
	var before: int = _relocations()
	_tick(zombie, 30.0, 8.0, 0.05)
	assert_eq(_relocations(), before, "kept walking, never moved to the spawn")
	assert_eq(zombie._stuck_watch.unreachable_time, 0.0)


func test_zombie_in_reach_is_not_stuck() -> void:
	_point(Vector3(40, 0, 0))
	var zombie: Zombie = _zombie(Vector3.ZERO)
	var before: int = _relocations()
	_tick(zombie, 25.0, 1.0)
	assert_eq(_relocations(), before, "standing next to its target is not stuck")


func test_far_zombie_relocates_after_15_seconds() -> void:
	_point(Vector3(40, 0, 0))
	var zombie: Zombie = _zombie(Vector3.ZERO)
	var before: int = _relocations()
	_tick(zombie, 14.0, 70.0, 0.05)
	assert_eq(_relocations(), before, "not yet at 14 s")
	_tick(zombie, 1.5, 70.0, 0.05)
	assert_eq(_relocations(), before + 1, "far for 15 s relocates")


func test_fallen_zombie_relocates_at_once() -> void:
	_point(Vector3(40, 0, 0))
	var zombie: Zombie = _zombie(Vector3(0, -60, 0))
	var before: int = _relocations()
	_tick(zombie, 0.1, 8.0)
	assert_eq(_relocations(), before + 1, "relocated at once")
	assert_gt(zombie.global_position.y, -50.0, "back on the map")


func test_spawn_a_player_can_see_is_not_used() -> void:
	var player: Player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0, 0)
	var open: ZombieSpawnPoint = _point(Vector3(20, 0, 0))
	var behind_wall: ZombieSpawnPoint = _point(Vector3(-20, 0, 0))
	_wall()
	await wait_physics_frames(3)
	assert_true(spawner._seen(open.global_position), "open spawn is in sight")
	assert_false(spawner._seen(behind_wall.global_position), "spawn behind the wall is hidden")
	for i: int in 10:
		var spot: Dictionary = spawner._pick_hidden_spot(10.0)
		assert_eq(spot.get("marker", &""), behind_wall.name)


func test_placed_point_is_checked_not_just_the_marker() -> void:
	var player: Player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0, 0)
	var edge: ZombieSpawnPoint = _point(Vector3(-20, 0, 9.6))
	_wall()
	await wait_physics_frames(3)
	assert_false(spawner._seen(edge.global_position), "the marker itself is just hidden")
	spawner.session.rng.seed = 1
	var rejected: int = 0
	for i: int in 40:
		var spot: Dictionary = spawner._pick_hidden_spot(10.0)
		if spot.is_empty():
			rejected += 1
			continue
		assert_false(spawner._seen(spot["point"]), "the final point is hidden too")
		assert_gte(spawner._distance_to_nearest_player(spot["point"]), 10.0)
	assert_gt(rejected, 0, "jitter that lands in sight is rejected")


func _wall() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1, 10, 10)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.global_position = Vector3(-10, 0, 0)


func test_coop_point_is_not_used_below_three_players() -> void:
	var coop: ZombieSpawnPoint = _point(Vector3(40, 0, 0))
	coop.min_players = 3
	var normal: ZombieSpawnPoint = _point(Vector3(-40, 0, 0))
	for i: int in 10:
		assert_eq(spawner._pick_hidden_spot(10.0).get("marker", &""), normal.name)


func test_no_hidden_spawn_means_retry() -> void:
	var zombie: Zombie = _zombie(Vector3.ZERO)
	assert_false(spawner.relocate(zombie, &"unreachable"), "no spawn points: no relocate")
	assert_eq(zombie.global_position, Vector3.ZERO)


func test_last_two_zombies_sprint_after_30_seconds() -> void:
	var director: WaveDirector = WaveDirector.new()
	director.rules = RULES
	director.spawner = spawner
	director.session = spawner.session
	add_child_autofree(director)
	director.set_physics_process(false)
	var a: Zombie = _zombie(Vector3.ZERO)
	var b: Zombie = _zombie(Vector3(3, 0, 0))
	director.phase = WaveDirector.Phase.CLEARING
	for i: int in 290:
		director._tick_last_few(0.1)
	assert_lt(a._speed, 5.0, "not yet at 29 s")
	for i: int in 20:
		director._tick_last_few(0.1)
	assert_almost_eq(a._speed, 5.6, 0.001, "sprint tier")
	assert_almost_eq(b._speed, 5.6, 0.001, "sprint tier")


func test_three_left_do_not_hurry() -> void:
	var director: WaveDirector = WaveDirector.new()
	director.rules = RULES
	director.spawner = spawner
	add_child_autofree(director)
	director.set_physics_process(false)
	var a: Zombie = _zombie(Vector3.ZERO)
	_zombie(Vector3(3, 0, 0))
	_zombie(Vector3(6, 0, 0))
	for i: int in 400:
		director._tick_last_few(0.1)
	assert_lt(a._speed, 5.0)

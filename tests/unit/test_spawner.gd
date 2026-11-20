extends GutTest

const RULES: WaveRules = preload("res://content/waves/default_waves.tres")


func test_missing_spawn_group_is_recorded_in_the_structured_log() -> void:
	var spawner: Spawner = Spawner.new()
	spawner.spawn_group = &"test_missing_spawn_points"
	add_child_autofree(spawner)
	var before: int = Log.event_counts.get("waves.spawn_points_missing", 0)
	assert_null(spawner._pick_marker(0.0))
	assert_eq(Log.event_counts.get("waves.spawn_points_missing", 0), before + 1)
	var record: Dictionary = Log.problems["waves.spawn_points_missing|"]["first"]
	assert_eq(record["level"], "warn")
	assert_eq(record["data"]["spawn_group"], String(spawner.spawn_group))


func _spawner() -> Spawner:
	var spawner: Spawner = Spawner.new()
	spawner.session = GameSession.new()
	autofree(spawner.session)
	add_child_autofree(spawner)
	return spawner


func _zombie(spawner: Spawner, point: Vector3) -> Zombie:
	var data: Array = ["res://content/enemies/zombie_walker.tres", Net.allocate_id(), 1.0, 1.0, 1.0, ^"", point]
	var zombie: Zombie = spawner._create(data) as Zombie
	spawner.add_child(zombie)
	zombie.set_physics_process(false)
	zombie.state = Zombie.State.CHASING
	return zombie


func test_spawned_zombies_join_the_live_list_and_leave_it_when_freed() -> void:
	var spawner: Spawner = _spawner()
	var a: Zombie = _zombie(spawner, Vector3.ZERO)
	var b: Zombie = _zombie(spawner, Vector3(3, 0, 0))
	assert_eq(spawner.zombies, [a, b] as Array[Zombie])
	assert_same(a.neighbours, spawner.zombies)
	assert_eq(spawner.alive_count(), 2)
	b.free()
	assert_eq(spawner.zombies, [a] as Array[Zombie])
	assert_eq(spawner.alive_count(), 1)


func test_separation_pushes_off_neighbours_without_the_enemies_group() -> void:
	var spawner: Spawner = _spawner()
	var a: Zombie = _zombie(spawner, Vector3.ZERO)
	var b: Zombie = _zombie(spawner, Vector3(0.5, 0, 0))
	b.remove_from_group(&"enemies")
	assert_lt(a._separation().x, 0.0)
	b.state = Zombie.State.DEAD
	assert_eq(a._separation(), Vector3.ZERO)


func test_zombies_of_another_spawner_do_not_push() -> void:
	var a: Zombie = _zombie(_spawner(), Vector3.ZERO)
	_zombie(_spawner(), Vector3(0.5, 0, 0))
	assert_eq(a._separation(), Vector3.ZERO)


func test_speed_mix_enemies_roll_a_design_tier() -> void:
	var spawner: Spawner = _spawner()
	spawner.session.rng.seed = 3
	var walker: EnemyData = load("res://content/enemies/zombie_walker.tres") as EnemyData
	var rules: WaveRules = RULES
	assert_almost_eq(spawner._speed_multiplier(walker, 1, rules) * walker.move_speed, 1.2, 0.0001)
	for i: int in 20:
		var speed: float = spawner._speed_multiplier(walker, 20, rules) * walker.move_speed
		assert_true(
			is_equal_approx(speed, 2.6) or is_equal_approx(speed, 4.2) or is_equal_approx(speed, 5.6),
			"round 20 speed %.2f is a design tier" % speed
		)


func test_speed_mix_zombie_moves_at_its_tier_exactly() -> void:
	var spawner: Spawner = _spawner()
	var walker_path: String = "res://content/enemies/zombie_walker.tres"
	var data: Array = [walker_path, Net.allocate_id(), 1.0, 2.6 / 1.2, 1.0, ^"", Vector3.ZERO]
	var zombie: Zombie = spawner._create(data) as Zombie
	autofree(zombie)
	assert_almost_eq(zombie._speed, 2.6, 0.0001)


func test_fixed_speed_enemies_keep_their_own_speed() -> void:
	var spawner: Spawner = _spawner()
	var bloater: EnemyData = load("res://content/enemies/zombie_bloater.tres") as EnemyData
	var rules: WaveRules = RULES
	assert_eq(spawner._speed_multiplier(bloater, 20, rules), 1.0)


func test_coop_points_wait_for_three_players() -> void:
	var spawner: Spawner = _spawner()
	spawner.spawn_group = &"test_coop_spawn"
	var point: ZombieSpawnPoint = ZombieSpawnPoint.new()
	point.min_players = 3
	point.add_to_group(spawner.spawn_group)
	add_child_autofree(point)
	var players: Array[Node3D] = []
	for i: int in 3:
		var player: Node3D = Node3D.new()
		player.position = Vector3(100, 0, 0)
		add_child_autofree(player)
		players.append(player)
	players[0].add_to_group(&"players")
	assert_null(spawner._pick_marker(0.0), "1 player: the co-op point is skipped")
	players[1].add_to_group(&"players")
	assert_null(spawner._pick_marker(0.0), "2 players: still skipped")
	players[2].add_to_group(&"players")
	assert_same(spawner._pick_marker(0.0), point, "3 players: it can be picked")


func test_pack_points_must_be_open_and_far_enough() -> void:
	var spawner: Spawner = _spawner()
	spawner.spawn_group = &"test_pack_spawn"
	var near: ZombieSpawnPoint = ZombieSpawnPoint.new()
	near.position = Vector3(2, 0, 0)
	var far: ZombieSpawnPoint = ZombieSpawnPoint.new()
	far.position = Vector3(40, 0, 0)
	for point: ZombieSpawnPoint in [near, far]:
		point.add_to_group(spawner.spawn_group)
		add_child_autofree(point)
	var player: Node3D = Node3D.new()
	add_child_autofree(player)
	player.add_to_group(&"players")
	assert_same(spawner._pick_marker(12.0, true), far, "the far open point")
	far.barrier = Barrier.new()
	autofree(far.barrier)
	assert_null(spawner._pick_marker(12.0, true), "a near open point is not used for a pack")
	assert_same(spawner._pick_marker(12.0), far, "the normal pick takes the far window instead")

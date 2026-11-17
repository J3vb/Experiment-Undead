extends GutTest


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

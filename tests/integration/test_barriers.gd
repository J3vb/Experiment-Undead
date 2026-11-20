## Window barriers on Halcyon Labs: every window spawn has one, zombies tear
## the planks and vault in, queue when the window's slots are full, swipe players through the gap, players repair
## planks for capped points and cannot leave through a window.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession
var player: Player
var level: Level


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	session.rng_seed = 7
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	player = session.get_players()[0]
	level = session.level


func after_each() -> void:
	get_tree().paused = false


func _barrier(barrier_name: String) -> Barrier:
	return level.get_node("Barriers/" + barrier_name) as Barrier


func _first_zombie() -> Zombie:
	await wait_until(func() -> bool: return not get_tree().get_nodes_in_group(&"enemies").is_empty(), 15.0, "spawn")
	var all: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	return all[0] as Zombie if not all.is_empty() else null


func test_every_window_spawn_has_a_barrier_facing_the_room() -> void:
	var windows: int = 0
	for node: Node in level.find_children("*", "Marker3D"):
		var point: ZombieSpawnPoint = node as ZombieSpawnPoint
		if point == null or point.barrier == null:
			continue
		windows += 1
		var spawn: Vector3 = point.global_position
		assert_lt(
			spawn.distance_to(point.barrier.outside_point()),
			spawn.distance_to(point.barrier.inside_point()),
			"%s: the zombie side of the barrier faces its spawn point" % point.name
		)
	assert_eq(windows, 16, "16 windows per the maps doc")
	assert_eq(get_tree().get_nodes_in_group(&"barriers").size(), 16)
	assert_eq(_barrier("LoadingDock1").planks, Barrier.PLANKS)
	assert_eq(Barrier.PLANKS, 6, "6 planks per the AI doc")


func test_zombie_tears_through_and_climbs_in() -> void:
	var zombie: Zombie = await _first_zombie()
	assert_not_null(zombie)
	if zombie == null:
		return
	player.global_position = level.get_player_spawn().origin
	var barrier: Barrier = zombie.barrier
	assert_not_null(barrier, "dock zombies spawn behind a window")
	await wait_until(func() -> bool: return zombie.state == Zombie.State.ENTERING, 3.0, "zombie stood up")
	await wait_until(func() -> bool: return barrier.planks < Barrier.PLANKS, 6.0, "first plank torn")
	assert_lt(barrier.planks, Barrier.PLANKS, "zombie tears planks")
	while barrier.planks > 1:
		barrier.tear_plank()
	await wait_until(func() -> bool: return zombie.entry.vault_progress() >= 0.0, 6.0, "vault starts")
	assert_gt(zombie.entry.vault_progress(), -1.0, "zombie vaults through the open window")
	await wait_until(func() -> bool: return zombie.state == Zombie.State.CHASING, 8.0, "climbed in")
	assert_true(barrier.is_broken())
	assert_null(zombie.barrier, "barrier forgotten once inside")
	var inward: float = (zombie.global_position - barrier.global_position).dot(barrier.global_basis.z)
	assert_gt(inward, 0.3, "zombie is on the room side")


func test_zombie_swipes_a_player_through_the_gap() -> void:
	var zombie: Zombie = await _first_zombie()
	if zombie == null:
		fail_test("no zombie")
		return
	var barrier: Barrier = zombie.barrier
	await wait_until(func() -> bool: return barrier.planks < Barrier.PLANKS, 6.0, "zombie at the window")
	player.global_position = barrier.global_position + barrier.global_basis.z * 0.5
	await wait_until(func() -> bool: return zombie.state == Zombie.State.ATTACKING, 3.0, "swipe")
	assert_eq(zombie.state, Zombie.State.ATTACKING, "player at the window gets swiped")
	await wait_until(func() -> bool: return zombie.state == Zombie.State.ENTERING, 2.0, "back to the planks")
	assert_eq(zombie.state, Zombie.State.ENTERING, "still outside after the swipe")


func test_repair_adds_a_plank_and_pays() -> void:
	var barrier: Barrier = _barrier("GuardPost1")
	assert_eq(barrier.get_prompt(player), "", "nothing to repair")
	barrier.tear_plank()
	barrier.tear_plank()
	assert_eq(barrier.get_prompt(player), "Hold to repair barrier [F]")
	assert_gt(barrier.hold_interval(player), Barrier.REPAIR_TIME, "a held key repairs without hitting the cooldown")
	var points: int = player.wallet.points
	barrier.interact(player)
	assert_eq(barrier.planks, Barrier.PLANKS - 1)
	assert_eq(player.wallet.points, points + 10, "10 points per plank")
	assert_true((barrier.get_node("Planks/Plank4") as Node3D).visible, "repaired plank shows")
	assert_false((barrier.get_node("Planks/Plank5") as Node3D).visible, "missing plank hidden")
	barrier.interact(player)
	assert_eq(barrier.planks, Barrier.PLANKS - 1, "one plank per %.1f s" % Barrier.REPAIR_TIME)
	await wait_seconds(Barrier.REPAIR_TIME + 0.1)
	barrier.interact(player)
	assert_eq(barrier.planks, Barrier.PLANKS)


func test_repair_points_are_capped_per_round() -> void:
	var points: int = player.wallet.points
	for i: int in 60:
		session.economy.pay_repair(player)
	assert_eq(player.wallet.points, points + 500, "500 points a round from repairs")
	Events.round_ended.emit(1)
	session.economy.pay_repair(player)
	assert_eq(player.wallet.points, points + 510, "cap resets each round")


func test_players_cannot_leave_through_a_window() -> void:
	assert_true(player.collision_mask & Layers.BARRIER != 0, "players collide with barriers")
	var barrier: Barrier = _barrier("GuardPost1")
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		barrier.inside_point() + Vector3.UP, barrier.outside_point() + Vector3.UP, Layers.BARRIER
	)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	assert_false(hit.is_empty(), "the window is shut for players")
	barrier.planks = 0
	hit = level.get_world_3d().direct_space_state.intersect_ray(query)
	assert_false(hit.is_empty(), "even with every plank gone")


func test_zombie_waits_in_the_queue_when_slots_are_full() -> void:
	var zombie: Zombie = await _first_zombie()
	if zombie == null:
		fail_test("no zombie")
		return
	var barrier: Barrier = zombie.barrier
	var holders: Array[Node3D] = []
	for i: int in Barrier.SLOTS:
		var holder: Node3D = Node3D.new()
		add_child_autofree(holder)
		holder.global_position = barrier.slot_point(i)
		barrier.claim_slot(holder)
		holders.append(holder)
	await wait_seconds(5.0)
	assert_eq(barrier.planks, Barrier.PLANKS, "a queued zombie does not tear planks")
	assert_lt(
		zombie.global_position.distance_to(barrier.queue_point(zombie.net_id)), 0.6, "it waits at its queue point"
	)
	barrier.release(holders[1])
	await wait_until(func() -> bool: return barrier.planks < Barrier.PLANKS, 6.0, "slot taken, tearing")
	assert_lt(barrier.planks, Barrier.PLANKS, "the freed slot lets it reach the planks")

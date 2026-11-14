## Boots a real match headless and plays it a little: navmesh bakes,
## zombies spawn and chase, shots kill, points and XP pay out, zombies hurt
## the player, and a round ends.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession
var player: Player


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	var rules: WaveRules = (session.wave_rules.duplicate(true)) as WaveRules
	rules.first_round_delay = 0.2
	rules.spawn_interval_start = 0.2
	rules.spawn_interval_min = 0.2
	rules.min_spawn_distance = 12.0
	session.wave_rules = rules
	session.rng_seed = 1234
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 10.0, "navmesh baked")
	player = session.get_players()[0]


func after_each() -> void:
	get_tree().paused = false


func _zombies() -> Array[Zombie]:
	var out: Array[Zombie] = []
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var z: Zombie = n as Zombie
		if z and z.state != Zombie.State.DEAD:
			out.append(z)
	return out


func _wait_for_zombie() -> Zombie:
	await wait_until(func() -> bool: return not _zombies().is_empty(), 5.0, "a zombie spawned")
	var all: Array[Zombie] = _zombies()
	return all[0] if not all.is_empty() else null


func test_navmesh_has_paths() -> void:
	var map: RID = session.level.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(24, 0, 58), Vector3(44, 0, 50), true)
	assert_gt(path.size(), 1, "path across the Loading Dock")
	assert_almost_eq(path[path.size() - 1].distance_to(Vector3(44, 0, 50)), 0.0, 1.0)


func test_player_spawns_with_loadout() -> void:
	watch_signals(Events)
	player.weapons.give(Content.weapon(&"rifle_ar"))
	assert_signal_emitted_with_parameters(Events, "weapon_acquired", [player, &"rifle_ar"])
	assert_eq(player.weapons.weapons.size(), 2)
	assert_eq(player.wallet.points, 500)
	assert_true(player.is_alive())


func test_zombie_chases_player() -> void:
	var z: Zombie = await _wait_for_zombie()
	assert_not_null(z)
	if z == null:
		return
	await wait_seconds(1.2)
	var before: float = z.global_position.distance_to(player.global_position)
	await wait_seconds(2.5)
	var after: float = z.global_position.distance_to(player.global_position)
	assert_lt(after, before - 1.0, "zombie closed in (%.1f -> %.1f)" % [before, after])


func test_headshots_kill_and_pay() -> void:
	var z: Zombie = await _wait_for_zombie()
	if z == null:
		fail_test("no zombie")
		return
	watch_signals(Events)
	var weapon: Weapon = player.weapons.current
	weapon.ads_progress = 1.0
	var shots: int = 0
	while z.state != Zombie.State.DEAD and shots < 15:
		var head: Vector3 = z.global_position + Vector3(0, 1.68, 0)
		player.camera.look_at(head)
		weapon.fire()
		shots += 1
		await wait_physics_frames(2)
	assert_eq(z.state, Zombie.State.DEAD, "zombie died after %d shots" % shots)
	assert_signal_emitted(Events, "enemy_killed")
	assert_gt(player.wallet.points, 500, "points paid")
	assert_gt(session.progression.get_xp(player), 0, "xp paid")


func test_zombie_hurts_player() -> void:
	var z: Zombie = await _wait_for_zombie()
	if z == null:
		fail_test("no zombie")
		return
	await wait_seconds(1.0)
	z.global_position = player.global_position + Vector3(0, 0, -1.1)
	await wait_until(func() -> bool: return player.health.current < player.health.max_health, 4.0, "player took damage")
	assert_lt(player.health.current, player.health.max_health)


func test_round_ends_when_all_dead() -> void:
	watch_signals(Events)
	var deadline: float = 15.0
	while deadline > 0.0 and get_signal_emit_count(Events, "round_ended") == 0:
		for z: Zombie in _zombies():
			z.health.take_damage(DamageInfo.create(10000.0, player))
		await wait_seconds(0.2)
		deadline -= 0.2
	assert_signal_emitted(Events, "round_ended")
	assert_eq(session.director.round_number, 1)


func test_holding_trigger_through_reload_fires_one_shot_per_interval() -> void:
	player.set_physics_process(false)
	var weapon: Weapon = player.weapons.current
	weapon.trigger_held = true
	weapon.instance.ammo_in_mag = 0
	assert_true(weapon.start_reload())
	var dt: float = 1.0 / 60.0
	var guard: int = 0
	while weapon.is_reloading() and guard < 600:
		weapon.tick(dt)
		guard += 1
	assert_false(weapon.is_reloading(), "reload finished")
	assert_gte(weapon.instance.ammo_in_mag, weapon.data.magazine_size - 1, "no banked burst after reload")
	weapon.tick(dt)
	assert_gte(weapon.instance.ammo_in_mag, weapon.data.magazine_size - 2, "normal fire rate afterwards")


func test_zombie_cannot_hit_through_walls() -> void:
	var z: Zombie = await _wait_for_zombie()
	if z == null:
		fail_test("no zombie")
		return
	# Generator Hall and Main Corridor share the wall at z = 26 (door cut at x 23..25).
	player.global_position = Vector3(20.0, 0.0, 26.7)
	z.global_position = Vector3(20.0, 0.0, 25.3)
	await wait_physics_frames(2)
	assert_false(z._can_see(player), "wall blocks the swing")
	z.global_position = player.global_position + Vector3(1.2, 0.0, 0.0)
	await wait_physics_frames(2)
	assert_true(z._can_see(player), "open ground does not")

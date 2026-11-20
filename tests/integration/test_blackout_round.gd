## A real headless match skipped to round 6: the lights go out, only Glowers spawn, in packs of 4 to 6 that share
## one leader, the count is 1.5x the round, and clearing the round brings the lights back and drops one Resupply.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession
var spawned: Array[Zombie] = []


func before_each() -> void:
	spawned.clear()
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	session.rng_seed = 1
	session.wave_rules = session.wave_rules.duplicate(true) as WaveRules
	session.wave_rules.first_round_delay = 1000.0
	session.wave_rules.spawn_interval_start = 0.02
	session.wave_rules.spawn_interval_min = 0.02
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	session.director.stop()
	Events.enemy_spawned.connect(_on_spawned)


func after_each() -> void:
	Events.enemy_spawned.disconnect(_on_spawned)


func _on_spawned(enemy: Node3D) -> void:
	if enemy is Zombie and not spawned.has(enemy):
		spawned.append(enemy as Zombie)


func _kill_all() -> void:
	for zombie: Zombie in session.spawner.zombies:
		if zombie.state != Zombie.State.DEAD:
			zombie.health.take_damage(DamageInfo.create(zombie.health.current, null))


func _pickups() -> Array[PowerUp]:
	var out: Array[PowerUp] = []
	for node: Node in session.level.get_children():
		if node is PowerUp and not node.is_queued_for_deletion():
			out.append(node as PowerUp)
	return out


func test_round_6_is_a_dark_glower_round_that_ends_with_a_resupply() -> void:
	watch_signals(Events)
	session.director.skip_to_round(6)
	assert_true(session.director.blackout, "round 6 is a Blackout")
	assert_signal_emitted_with_parameters(Events, "blackout_started", [6])
	var expected: int = session.wave_rules.get_blackout_count(6, 1)
	assert_eq(session.director.to_spawn, expected, "1.5x the round's count")
	for _i: int in 600:
		await wait_physics_frames(1)
		_kill_all()
		if session.director.phase == WaveDirector.Phase.INTERMISSION:
			break
	assert_eq(session.director.phase, WaveDirector.Phase.INTERMISSION, "the Blackout round was cleared")
	assert_eq(spawned.size(), expected)
	var packs: Dictionary[Zombie, int] = {}
	for zombie: Zombie in spawned:
		assert_eq(zombie.data.id, &"zombie_glower", "only Glowers in a Blackout")
		var leader: Zombie = zombie.pack_leader if zombie.pack_leader else zombie
		packs[leader] = packs.get(leader, 0) + 1
	var short: int = 0
	for leader: Zombie in packs:
		assert_null(leader.pack_leader, "a leader leads itself")
		assert_lte(packs[leader], session.wave_rules.pack_max)
		short += 1 if packs[leader] < session.wave_rules.pack_min else 0
	assert_lte(short, 1, "only the last pack may be short (what was left)")
	assert_false(session.director.blackout, "lights back after the round")
	assert_signal_emitted_with_parameters(Events, "blackout_ended", [6])
	var rewards: Array[PowerUp] = _pickups()
	assert_eq(rewards.size(), 1, "one Resupply for clearing the Blackout")
	if rewards.size() == 1:
		assert_eq(rewards[0].data.id, &"resupply")


func test_a_normal_round_has_no_blackout_or_reward() -> void:
	session.power_up_drops.drop_chance = 0.0
	session.director.skip_to_round(5)
	assert_false(session.director.blackout)
	session.director.set_blackout(true)
	assert_false(session.director.blackout_round, "the debug light switch is not a Blackout round")
	for _i: int in 600:
		await wait_physics_frames(1)
		_kill_all()
		if session.director.phase == WaveDirector.Phase.INTERMISSION:
			break
	assert_eq(_pickups().size(), 0, "no reward without a scheduled Blackout, even with the lights out")
	for zombie: Zombie in spawned:
		assert_ne(zombie.data.id, &"zombie_glower", "Glowers come only in Blackouts")


func test_packs_fit_under_a_small_alive_cap() -> void:
	session.wave_rules.max_alive = 3
	session.director.skip_to_round(6)
	var expected: int = session.director.to_spawn
	for _i: int in 600:
		await wait_physics_frames(1)
		assert_lte(session.spawner.alive_count(), 3, "never over the alive cap")
		_kill_all()
		if session.director.phase == WaveDirector.Phase.INTERMISSION:
			break
	assert_eq(session.director.phase, WaveDirector.Phase.INTERMISSION, "the round still ends")
	assert_eq(spawned.size(), expected)

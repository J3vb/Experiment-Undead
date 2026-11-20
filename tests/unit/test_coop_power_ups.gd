## Two ENet peers: server drops appear on the client, the server decides who
## collects them, the ammo lands on the PC that owns the guns, and timed
## power-ups reach every client and late joiner.
extends "res://tests/unit/coop_interaction_fixture.gd"

const RESUPPLY: String = "res://content/power_ups/resupply.tres"
const AMMO_PACK: String = "res://content/power_ups/ammo_pack.tres"
const PAYDAY: String = "res://content/power_ups/payday.tres"
const OVERKILL: PowerUpData = preload("res://content/power_ups/overkill.tres")
const STASIS: PowerUpData = preload("res://content/power_ups/stasis.tres")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const WAVES: WaveRules = preload("res://content/waves/default_waves.tres")
const RIFLE: WeaponData = preload("res://content/weapons/rifle_ar.tres")


func port() -> int:
	return 24715


func make_side(side_name: String) -> GameSession:
	var session: GameSession = CoopSide.make(self, side_name, [&"interactions", &"hit_claims"], build_level())
	_sessions.append(session)
	return session


func before_each() -> void:
	await super.before_each()
	for session: GameSession in [server, client]:
		_drops(session).session = session
		_drops(session).setup(session.level)


func _drops(session: GameSession) -> PowerUpDrops:
	return session.get_node("PowerUpDrops") as PowerUpDrops


func _pickups(session: GameSession) -> Array[PowerUp]:
	var out: Array[PowerUp] = []
	for node: Node in session.level.get_children():
		if node is PowerUp and not node.is_queued_for_deletion():
			out.append(node as PowerUp)
	return out


func _drop(path: String, at: Vector3) -> PowerUp:
	var pickup: PowerUp = _drops(server).drop(load(path) as PowerUpData, at)
	await wait_until(func() -> bool: return _pickups(client).size() == 1, 3.0, "the drop reached the client")
	return pickup


func _half_empty_gun() -> Weapon:
	var gun: Weapon = on_client().weapons.give(Content.weapon(&"kestrel_smg"))
	gun.instance.ammo_in_mag = 1
	gun.instance.ammo_reserve = 0
	return gun


func test_a_server_drop_appears_on_the_client() -> void:
	await _drop(RESUPPLY, Vector3(3, 0, 3))
	var copy: PowerUp = _pickups(client)[0]
	assert_eq(copy.data.id, &"resupply")
	assert_almost_eq(copy.position, Vector3(3, 0.8, 3), Vector3.ONE * 0.01)
	assert_false(copy.monitoring, "only the server checks who touches it")


func test_client_collects_resupply_and_its_own_guns_fill() -> void:
	var gun: Weapon = _half_empty_gun()
	var pickup: PowerUp = await _drop(RESUPPLY, Vector3(3, 0, 3))
	watch_signals(Events)
	pickup.collect(on_server())
	await wait_until(func() -> bool: return gun.instance.ammo_reserve == gun.data.max_reserve, 3.0, "refill granted")
	assert_eq(gun.instance.ammo_in_mag, gun.data.magazine_size)
	await wait_until(func() -> bool: return _pickups(client).is_empty(), 3.0, "the pickup left the client")
	assert_signal_emit_count(Events, "power_up_collected", 2, "flash on the server and on the client")
	assert_eq(get_signal_parameters(Events, "power_up_collected")[0], on_client())


func test_ammo_pack_adds_one_magazine_for_the_collector_only() -> void:
	var gun: Weapon = _half_empty_gun()
	var pickup: PowerUp = await _drop(AMMO_PACK, Vector3(3, 0, 3))
	pickup.collect(on_server())
	await wait_until(func() -> bool: return gun.instance.ammo_reserve == gun.data.magazine_size, 3.0, "pack granted")
	assert_eq(gun.instance.ammo_in_mag, 1, "a pack fills the reserve, not the magazine")


func test_a_timed_out_drop_leaves_the_client() -> void:
	var pickup: PowerUp = await _drop(RESUPPLY, Vector3(3, 0, 3))
	pickup.age = PowerUp.LIFETIME
	await wait_until(func() -> bool: return _pickups(client).is_empty(), 3.0, "despawned on the client")
	var copy_count: int = _pickups(client).size()
	assert_eq(copy_count, 0)


func test_client_copy_never_frees_itself() -> void:
	await _drop(RESUPPLY, Vector3(3, 0, 3))
	var copy: PowerUp = _pickups(client)[0]
	copy.age = PowerUp.LIFETIME + 1.0
	await wait_physics_frames(3)
	assert_true(is_instance_valid(copy) and not copy.is_queued_for_deletion(), "only the server ends a pickup")


func test_late_joiner_sees_a_live_drop_with_its_age() -> void:
	var pickup: PowerUp = await _drop(RESUPPLY, Vector3(3, 0, 3))
	pickup.age = 21.0
	late = make_side("InteractLate")
	add_player(late, client_id)
	_drops(late).session = late
	_drops(late).setup(late.level)
	await join(late)
	await wait_until(func() -> bool: return _pickups(late).size() == 1, 3.0, "the joiner got the drop")
	assert_almost_eq(_pickups(late)[0].age, 21.0, 0.5, "already blinking for the joiner")


func test_a_payday_timer_reaches_the_client() -> void:
	var payday: PowerUpData = load(PAYDAY) as PowerUpData
	var pickup: PowerUp = await _drop(PAYDAY, Vector3(3, 0, 3))
	watch_signals(Events)
	pickup.collect(on_server())
	await wait_until(
		func() -> bool: return get_signal_emit_count(Events, "power_up_timer_started") == 2, 3.0, "timer relayed"
	)
	assert_eq(get_signal_parameters(Events, "power_up_timer_started")[0], payday)
	assert_true(_drops(server).is_active(PowerUpData.Effect.PAYDAY))
	var row: PowerUpTimers = client.hud.get_node(^"Root/PowerUpTimers") as PowerUpTimers
	assert_almost_eq(row.time_left(payday), 30.0, 0.5, "the client's HUD shows the ring")


func test_payday_doubles_a_client_players_kill_points() -> void:
	var killer: Player = on_server()
	killer.wallet.set_points(0)
	_drops(server).start_timer(load(PAYDAY) as PowerUpData)
	var corpse: Node3D = Node3D.new()
	add_child_autofree(corpse)
	_drops(server).drop_chance = 0.0
	Events.enemy_killed.emit(corpse, DamageInfo.create(1.0, killer))
	assert_eq(killer.wallet.points, server.economy.rules.points_per_kill * Economy.PAYDAY_MULTIPLIER)


func test_late_joiner_gets_the_time_left() -> void:
	var payday: PowerUpData = load(PAYDAY) as PowerUpData
	_drops(server).start_timer(payday)
	_drops(server)._physics_process(12.0)
	late = make_side("InteractLate")
	add_player(late, client_id)
	_drops(late).session = late
	_drops(late).setup(late.level)
	await join(late)
	var row: PowerUpTimers = late.hud.get_node(^"Root/PowerUpTimers") as PowerUpTimers
	await wait_until(func() -> bool: return row.time_left(payday) > 0.0, 3.0, "the joiner asked for timers")
	assert_almost_eq(row.time_left(payday), 18.0, 0.5, "the joiner's ring shows the time left, not a full one")


func _zombie_pair(round_number: int) -> Array[Zombie]:
	CoopSide.add_spawn_point(server, Vector3(0, 0, -4))
	var zombie: Zombie = server.spawner.spawn(WALKER, round_number, WAVES)
	zombie.set_physics_process(false)
	zombie.position = Vector3(0, 0, -4)
	zombie.state = Zombie.State.CHASING
	var path: NodePath = NodePath(String(zombie.name))
	await wait_until(func() -> bool: return client.spawner.has_node(path), 3.0, "zombie replicated")
	return [zombie, client.spawner.get_node(path) as Zombie]


func test_a_client_sees_stasis_and_its_ice() -> void:
	var pair: Array[Zombie] = await _zombie_pair(1)
	_drops(server).start_timer(STASIS)
	await wait_until(func() -> bool: return pair[1].stasis, 3.0, "stasis synced")
	var mesh: MeshInstance3D = pair[1].visual.find_children("*", "MeshInstance3D", true, false)[0]
	assert_not_null(mesh.material_overlay, "the client shows the ice")
	_drops(server)._physics_process(STASIS.duration + 0.5)
	await wait_until(func() -> bool: return not pair[1].stasis, 3.0, "stasis end synced")


func test_a_clients_hit_claim_kills_under_overkill() -> void:
	var pair: Array[Zombie] = await _zombie_pair(20)
	_drops(server).start_timer(OVERKILL)
	var claims: HitClaims = client.hit_claims
	claims.claim_hit.rpc_id(1, pair[0].name, DamageInfo.Zone.BODY, RIFLE.damage, RIFLE.id, pair[0].global_position)
	await wait_until(func() -> bool: return pair[0].health.is_dead, 3.0, "one claimed body shot killed")
	assert_true(pair[0].health.is_dead)

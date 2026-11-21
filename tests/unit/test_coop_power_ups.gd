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


func test_purge_and_scrap_kit_reach_the_client() -> void:
	var pair: Array[Zombie] = await _zombie_pair(1)
	var barrier: Barrier = target(server, "Barrier") as Barrier
	barrier._set_planks(0)
	var copy: Barrier = target(client, "Barrier") as Barrier
	await wait_until(func() -> bool: return copy.planks == 0, 3.0, "broken barrier synced")
	_drops(server)._spawn(load("res://content/power_ups/purge.tres") as PowerUpData, Vector3(3, 0, 3)).collect(
		on_server()
	)
	_drops(server)._spawn(load("res://content/power_ups/scrap_kit.tres") as PowerUpData, Vector3(3, 0, 3)).collect(
		on_server()
	)
	await wait_until(func() -> bool: return pair[1].state == Zombie.State.DEAD, 3.0, "Purge death synced")
	await wait_until(func() -> bool: return copy.planks == Barrier.PLANKS, 3.0, "rebuilt planks synced")
	await wait_until(
		func() -> bool: return on_client().wallet.points == on_server().wallet.points, 3.0, "team points synced"
	)
	assert_eq(on_server().wallet.points, 600, "+400 and +200 for the client player")


func _crate(session: GameSession) -> SupplyCrate:
	for node: Node in session.level.get_children():
		if node is SupplyCrate and not node.is_queued_for_deletion():
			return node as SupplyCrate
	return null


## Drops a Supply Crate pickup at (1, 0, 1), collects it on the server, waits for the client's crate.
func _land_crate() -> void:
	var pickup: PowerUp = await _drop("res://content/power_ups/supply_crate.tres", Vector3(1, 0, 1))
	pickup.collect(on_server())
	await wait_until(func() -> bool: return _crate(client) != null, 3.0, "crate reached the client")


func test_a_client_opens_a_crate_and_takes_the_gun() -> void:
	await _land_crate()
	assert_eq(_crate(client).position, _crate(server).position)
	assert_eq(_crate(server).pool, target(server, "Vault").get("pool"), "rolls the level Vault's guns")
	client.interactions.request(on_client(), _crate(client))
	await wait_until(func() -> bool: return _crate(client).state == SupplyCrate.State.ROLLING, 3.0, "rolling")
	_crate(server)._timer = 0.0
	await wait_until(func() -> bool: return _crate(client).state == SupplyCrate.State.OFFERING, 3.0, "offer")
	var offer: WeaponData = _crate(server).offer
	assert_eq(_crate(client).offer, offer)
	assert_ne(_crate(client).get_prompt(on_client()), "", "the opener sees Take")
	server.interactions._time += 1.0
	client.interactions.request(on_client(), _crate(client))
	await wait_until(func() -> bool: return on_client().weapons.weapons.size() == 1, 3.0, "gun granted")
	assert_eq(on_client().weapons.current.data, offer)
	await wait_until(func() -> bool: return _crate(client) == null, 3.0, "crate gone on the client")


func test_a_late_joiner_sees_the_crate_and_cannot_take_its_gun() -> void:
	await _land_crate()
	client.interactions.request(on_client(), _crate(client))
	await wait_until(func() -> bool: return _crate(server).state == SupplyCrate.State.ROLLING, 3.0, "rolling")
	_crate(server)._timer = 0.0
	late = make_side("InteractLate")
	add_player(late, client_id)
	_drops(late).session = late
	_drops(late).setup(late.level)
	await join(late)
	var late_id: int = late.multiplayer.get_unique_id()
	add_player(server, late_id)
	add_player(client, late_id)
	var other: Player = add_player(late, late_id)
	await wait_until(func() -> bool: return _crate(late) != null, 3.0, "the joiner got the crate")
	assert_eq(_crate(late).position, _crate(server).position, "where it landed")
	await wait_until(func() -> bool: return _crate(late).state == SupplyCrate.State.OFFERING, 3.0, "late sees offer")
	assert_eq(_crate(late).get_prompt(other), "", "not the opener")
	late.interactions.request(other, _crate(late))
	await wait_physics_frames(6)
	assert_eq(_crate(server).state, SupplyCrate.State.OFFERING, "offer still waits for its opener")
	assert_eq(other.weapons.weapons.size(), 0)


func _host_gun() -> Weapon:
	var host: Player = add_player(server, 1)
	add_player(client, 1)
	var gun: Weapon = host.weapons.give(Content.weapon(&"kestrel_smg"))
	gun.instance.ammo_in_mag = 1
	gun.instance.ammo_reserve = 0
	return gun


func test_client_walking_into_a_drop_collects_it() -> void:
	var gun: Weapon = _half_empty_gun()
	var player: Player = on_server()
	await _drop(AMMO_PACK, player.global_position)
	await wait_until(func() -> bool: return gun.instance.ammo_reserve == gun.data.magazine_size, 3.0, "walk-in pickup")
	assert_true(_pickups(server).is_empty(), "the server ended the pickup")


func test_resupply_also_fills_the_hosts_own_guns() -> void:
	var host_gun: Weapon = _host_gun()
	var gun: Weapon = _half_empty_gun()
	var pickup: PowerUp = await _drop(RESUPPLY, Vector3(3, 0, 3))
	pickup.collect(on_server())
	await wait_until(func() -> bool: return gun.instance.ammo_reserve == gun.data.max_reserve, 3.0, "client refilled")
	assert_eq(host_gun.instance.ammo_reserve, host_gun.data.max_reserve, "the host's reserve is full")
	assert_eq(host_gun.instance.ammo_in_mag, host_gun.data.magazine_size, "the host's magazine is full")


func test_ammo_pack_leaves_other_players_guns_alone() -> void:
	var host_gun: Weapon = _host_gun()
	var gun: Weapon = _half_empty_gun()
	var pickup: PowerUp = await _drop(AMMO_PACK, Vector3(3, 0, 3))
	pickup.collect(on_server())
	await wait_until(func() -> bool: return gun.instance.ammo_reserve == gun.data.magazine_size, 3.0, "pack granted")
	await wait_physics_frames(3)
	assert_eq(host_gun.instance.ammo_reserve, 0, "the host's reserve is unchanged")
	assert_eq(host_gun.instance.ammo_in_mag, 1, "the host's magazine is unchanged")

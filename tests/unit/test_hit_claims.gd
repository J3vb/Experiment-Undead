## Two ENet peers exercise trusted claims, normal damage rewards and the
## client's immediate hit / synced-death kill markers.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const WAVES: WaveRules = preload("res://content/waves/default_waves.tres")
const RIFLE: WeaponData = preload("res://content/weapons/rifle_ar.tres")
const PORT: int = 24671

var server: HitClaims
var client: HitClaims
var claimant: Player
var host: Player
var mine: Player
var progression: ProgressionService


func _make_side(side_name: String) -> HitClaims:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var session: GameSession = GameSession.new()
	session.rng.seed = 7
	var world: Node3D = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var economy: Economy = Economy.new()
	economy.name = "Economy"
	economy.rules = load("res://content/economy/default_economy.tres")
	root.add_child(economy)
	var rewards: ProgressionService = ProgressionService.new()
	rewards.name = "Progression"
	root.add_child(rewards)
	session.spawner = Spawner.new()
	session.spawner.name = "Enemies"
	session.spawner.spawn_group = &"test_hit_claim_points"
	session.spawner.session = session
	root.add_child(session.spawner)
	session.players = PlayerSpawner.new()
	session.players.name = "PlayerSpawner"
	session.players.player_scene = PLAYER
	session.players.player_added.connect(_prepare_player.bind(session))
	root.add_child(session.players)
	var claims: HitClaims = HitClaims.new()
	claims.name = "HitClaims"
	claims.session = session
	root.add_child(claims)
	return claims


func _prepare_player(player: Player, session: GameSession) -> void:
	player.spawn(session, [RIFLE])
	player.set_physics_process(false)
	player.input_enabled = false


func before_each() -> void:
	server = _make_side("Server")
	client = _make_side("Client")
	progression = server.get_parent().get_node("Progression") as ProgressionService
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_hit_claim_points")
	marker.position = Vector3(0, 0, -4)
	server.get_parent().add_child(marker)
	await _connect_peers()
	var peer_id: int = client.multiplayer.get_unique_id()
	claimant = server.session.players.find_player(peer_id)
	host = server.session.players.find_player(1)
	mine = client.session.players.find_player(peer_id)
	watch_signals(Events)
	watch_signals(mine.weapons.current)


func _connect_peers() -> void:
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT, 2), OK)
	server.multiplayer.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client.multiplayer.multiplayer_peer = client_peer
	client.session.players.setup(client.get_parent().get_node("World") as Node3D, Transform3D.IDENTITY)
	server.session.players.setup(server.get_parent().get_node("World") as Node3D, Transform3D.IDENTITY)
	await wait_until(
		func() -> bool:
			var peer_id: int = client.multiplayer.get_unique_id()
			return (
				peer_id > 1
				and server.session.players.find_player(peer_id) != null
				and client.session.players.find_player(peer_id) != null
			),
		5.0,
		"players connected"
	)


func after_each() -> void:
	for claims: HitClaims in [client, server]:
		var root: Node = claims.get_parent()
		var path: NodePath = root.get_path()
		root.multiplayer.multiplayer_peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		for node: Node in claims.session.spawner.get_children():
			if node is Zombie:
				node.free()
		for node: Node in root.get_node("World").get_children():
			if node is Player:
				node.free()
		claims.session.free()
		root.free()
		get_tree().set_multiplayer(null, path)


func _zombies() -> Array[Zombie]:
	var zombie: Zombie = server.session.spawner.spawn(WALKER, 1, WAVES)
	zombie.set_physics_process(false)
	var path: NodePath = NodePath(String(zombie.name))
	await wait_until(func() -> bool: return client.session.spawner.has_node(path), 3.0, "zombie replicated")
	return [zombie, client.session.spawner.get_node(path) as Zombie]


func _claim(zombie_name: StringName, amount: float, point: Vector3 = Vector3.ZERO) -> void:
	client.claim_hit.rpc_id(1, zombie_name, DamageInfo.Zone.BODY, amount, RIFLE.id, point)


func _flush_claims() -> void:
	await wait_physics_frames(8)


func test_client_damage_kill_and_rewards_belong_to_the_claiming_player() -> void:
	var pair: Array[Zombie] = await _zombies()
	var zombie: Zombie = pair[0]
	var before_host: int = host.wallet.points
	var before_owner: int = claimant.wallet.points
	_claim(zombie.name, 34.0)
	await wait_until(func() -> bool: return zombie.health.current < zombie.health.max_health, 3.0, "claim damaged")
	assert_eq(zombie.health.current, 66.0)
	_claim(zombie.name, 34.0)
	_claim(zombie.name, 34.0)
	await wait_until(func() -> bool: return zombie.health.is_dead, 3.0, "claim killed")
	assert_eq(claimant.wallet.points, before_owner + 90)
	await wait_until(func() -> bool: return mine.wallet.points == claimant.wallet.points, 3.0, "owner points synced")
	assert_eq(mine.wallet.points, before_owner + 90)
	assert_eq(host.wallet.points, before_host)
	assert_eq(progression.get_xp(claimant), WALKER.xp_reward)
	assert_eq(progression.get_xp(host), 0)
	assert_signal_emit_count(Events, "enemy_killed", 1)
	var killed: Array = get_signal_parameters(Events, "enemy_killed")
	assert_eq((killed[1] as DamageInfo).attacker, claimant)


func test_dead_missing_out_of_range_excessive_and_invalid_claims_change_nothing() -> void:
	var pair: Array[Zombie] = await _zombies()
	var zombie: Zombie = pair[0]
	var before: int = claimant.wallet.points
	_claim(&"ZombieMissing", 34.0)
	_claim(zombie.name, 34.0, claimant.camera.global_position + Vector3(RIFLE.max_range + 3.0, 0, 0))
	_claim(zombie.name, RIFLE.damage * RIFLE.head_multiplier * 1.5 + 0.01)
	_claim(zombie.name, NAN)
	_claim(zombie.name, -1.0)
	client.claim_hit.rpc_id(1, zombie.name, 99, 34.0, RIFLE.id, Vector3.ZERO)
	client.claim_hit.rpc_id(1, zombie.name, DamageInfo.Zone.BODY, 34.0, &"missing", Vector3.ZERO)
	await _flush_claims()
	assert_eq(zombie.health.current, 100.0)
	assert_eq(claimant.wallet.points, before)
	zombie.health.take_damage(DamageInfo.create(100.0, null))
	_claim(zombie.name, 34.0)
	await _flush_claims()
	assert_eq(zombie.health.current, 0.0)
	assert_eq(claimant.wallet.points, before)


func test_claims_from_a_dead_player_are_refused() -> void:
	var pair: Array[Zombie] = await _zombies()
	var before: int = claimant.wallet.points
	claimant.health.is_dead = true
	_claim(pair[0].name, 34.0)
	await _flush_claims()
	assert_eq(pair[0].health.current, 100.0)
	assert_eq(claimant.wallet.points, before)


func test_claims_without_a_spawned_player_are_refused() -> void:
	var pair: Array[Zombie] = await _zombies()
	var players: PlayerSpawner = server.session.players
	server.session.players = PlayerSpawner.new()
	_claim(pair[0].name, 34.0)
	await _flush_claims()
	assert_eq(pair[0].health.current, 100.0)
	assert_signal_not_emitted(Events, "enemy_damaged")
	server.session.players.free()
	server.session.players = players


func test_one_second_limit_is_per_player_and_weapon_and_warns_once() -> void:
	var pair: Array[Zombie] = await _zombies()
	var zombie: Zombie = pair[0]
	var limit: int = floori(RIFLE.rounds_per_minute / 60.0 * RIFLE.pellets * 1.5 + 2.0)
	var warnings: int = Log.event_counts.get("net.hit_claim_rejected", 0)
	for index: int in limit + 5:
		_claim(zombie.name, 1.0)
	await _flush_claims()
	assert_eq(zombie.health.current, 100.0 - limit)
	assert_eq(Log.event_counts.get("net.hit_claim_rejected", 0), warnings + 1)
	client.claim_hit.rpc_id(1, zombie.name, DamageInfo.Zone.BODY, 1.0, &"pistol_service", Vector3.ZERO)
	await _flush_claims()
	assert_eq(zombie.health.current, 99.0 - limit, "a different weapon has a separate limit")
	server._physics_process(1.01)
	_claim(zombie.name, 1.0)
	await _flush_claims()
	assert_eq(zombie.health.current, 98.0 - limit, "the rolling window expires")


func test_hit_marker_is_immediate_and_kill_marker_waits_for_synced_dead_state() -> void:
	var pair: Array[Zombie] = await _zombies()
	var weapon: Weapon = mine.weapons.current
	var info: DamageInfo = DamageInfo.create(34.0, mine)
	info.weapon_id = RIFLE.id
	client.submit_hit(weapon, pair[1].head_zone, info)
	assert_signal_emit_count(weapon, "hit_landed", 1)
	assert_eq(get_signal_parameters(weapon, "hit_landed"), [false, true])
	assert_false(pair[1].health.is_dead, "trusted feedback never mutates client health")
	_claim(pair[0].name, 66.0)
	await wait_until(func() -> bool: return pair[1].state == Zombie.State.DEAD, 3.0, "death synced")
	await wait_physics_frames(2)
	assert_signal_emit_count(Events, "hit_confirmed", 2)
	assert_eq(get_signal_parameters(Events, "hit_confirmed"), [mine, true, true])


func test_kill_marker_survives_replacing_the_gun_that_hit() -> void:
	var pair: Array[Zombie] = await _zombies()
	var weapon: Weapon = mine.weapons.current
	var info: DamageInfo = DamageInfo.create(34.0, mine)
	info.weapon_id = RIFLE.id
	client.submit_hit(weapon, pair[1].head_zone, info)
	mine.weapons.replace_current(Content.weapon(&"pistol_service"))
	await wait_physics_frames(2)
	assert_false(is_instance_valid(weapon), "replaced gun was freed")
	_claim(pair[0].name, 66.0)
	await wait_until(func() -> bool: return pair[1].state == Zombie.State.DEAD, 3.0, "death synced")
	await wait_physics_frames(2)
	assert_signal_emit_count(Events, "hit_confirmed", 2)
	assert_eq(get_signal_parameters(Events, "hit_confirmed"), [mine, true, true])


func test_kill_marker_expires_after_half_a_second() -> void:
	var pair: Array[Zombie] = await _zombies()
	var weapon: Weapon = mine.weapons.current
	var info: DamageInfo = DamageInfo.create(1.0, mine)
	info.weapon_id = RIFLE.id
	client.submit_hit(weapon, pair[1].head_zone, info)
	client._physics_process(0.51)
	pair[1].state = Zombie.State.DEAD
	client._physics_process(0.01)
	assert_signal_emit_count(weapon, "hit_landed", 1)
	assert_signal_emit_count(Events, "hit_confirmed", 1)


func test_multiple_pending_hits_prune_freed_zombies_without_skipping_live_entries() -> void:
	var pairs: Array[Array] = []
	for index: int in 3:
		pairs.append(await _zombies())
	client.set_physics_process(false)
	for pair: Array in pairs:
		var info: DamageInfo = DamageInfo.create(1.0, mine)
		info.weapon_id = RIFLE.id
		client.submit_hit(mine.weapons.current, (pair[1] as Zombie).head_zone, info)
	assert_signal_emit_count(Events, "hit_confirmed", 3)
	(pairs[0][0] as Zombie).queue_free()
	await wait_until(func() -> bool: return not is_instance_valid(pairs[0][1]), 3.0, "first zombie despawned")
	(pairs[1][1] as Zombie).state = Zombie.State.DEAD
	client._physics_process(0.1)
	assert_signal_emit_count(Events, "hit_confirmed", 4)
	(pairs[2][1] as Zombie).state = Zombie.State.DEAD
	client._physics_process(0.1)
	assert_signal_emit_count(Events, "hit_confirmed", 5)
	client._physics_process(0.1)
	assert_signal_emit_count(Events, "hit_confirmed", 5, "each tracked death confirms once")


func test_repeated_hit_refreshes_kill_window_and_remembers_the_latest_zone() -> void:
	var pair: Array[Zombie] = await _zombies()
	client.set_physics_process(false)
	var info: DamageInfo = DamageInfo.create(1.0, mine)
	info.weapon_id = RIFLE.id
	client.submit_hit(mine.weapons.current, pair[1].head_zone, info)
	client._physics_process(0.4)
	client.submit_hit(mine.weapons.current, pair[1].hit_zones[1], info)
	client._physics_process(0.2)
	pair[1].state = Zombie.State.DEAD
	client._physics_process(0.01)
	assert_signal_emit_count(Events, "hit_confirmed", 3, "one kill inside the latest hit's window")
	assert_eq(get_signal_parameters(Events, "hit_confirmed"), [mine, true, false])
	client._physics_process(0.01)
	assert_signal_emit_count(Events, "hit_confirmed", 3)


func test_solo_weapon_trace_still_applies_direct_hit_zone_damage() -> void:
	var pair: Array[Zombie] = await _zombies()
	var zombie: Zombie = pair[0]
	var weapon: Weapon = host.weapons.current
	var body: HitZone = zombie.hit_zones[1]
	for zone: HitZone in pair[1].hit_zones:
		zone.set_enabled(false)
	zombie.position = Vector3(0, 0, -4)
	zombie.visual.position = Vector3.ZERO
	await wait_physics_frames(2)
	var origin: Vector3 = body.global_position + Vector3(0, 0, 2)
	var before: float = zombie.health.current
	weapon._trace(origin, Vector3.FORWARD)
	assert_lt(zombie.health.current, before, "server keeps Weapon's direct damage path")

## Real client claims exercise server Prototype effects, synced frost and cosmetic arcs.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const WAVES: WaveRules = preload("res://content/waves/default_waves.tres")
const CRYO: WeaponData = preload("res://content/weapons/cryo_lance.tres")
const SYNAPSE: WeaponData = preload("res://content/weapons/synapse.tres")
const PORT: int = 24683

var _server: HitClaims
var _client: HitClaims
var _claimant: Player
var _host: Player
var _mine: Player
var _progression: ProgressionService


func _side(side_name: String) -> HitClaims:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var session: GameSession = GameSession.new()
	session.rng.seed = 83
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
	session.spawner.spawn_group = &"test_prototype_claim_points"
	session.spawner.session = session
	root.add_child(session.spawner)
	session.players = PlayerSpawner.new()
	session.players.name = "Players"
	session.players.player_scene = PLAYER
	session.players.player_added.connect(_prepare.bind(session))
	root.add_child(session.players)
	var claims: HitClaims = HitClaims.new()
	claims.name = "HitClaims"
	claims.session = session
	root.add_child(claims)
	return claims


func _prepare(player: Player, session: GameSession) -> void:
	player.spawn(session, [CRYO, SYNAPSE])
	player.set_physics_process(false)
	player.input_enabled = false


func before_each() -> void:
	_server = _side("Server")
	_client = _side("Client")
	_progression = _server.get_parent().get_node("Progression") as ProgressionService
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_prototype_claim_points")
	_server.get_parent().add_child(marker)
	await _connect()
	var peer: int = _client.multiplayer.get_unique_id()
	_claimant = _server.session.players.find_player(peer)
	_host = _server.session.players.find_player(1)
	_mine = _client.session.players.find_player(peer)
	watch_signals(Events)


func _connect() -> void:
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT, 2), OK)
	_server.multiplayer.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	_client.multiplayer.multiplayer_peer = client_peer
	_client.session.players.setup(_client.get_parent().get_node("World") as Node3D, Transform3D.IDENTITY)
	_server.session.players.setup(_server.get_parent().get_node("World") as Node3D, Transform3D.IDENTITY)
	await wait_until(
		func() -> bool:
			var peer: int = _client.multiplayer.get_unique_id()
			return (
				peer > 1
				and _server.session.players.find_player(peer) != null
				and _client.session.players.find_player(peer) != null
			),
		5.0,
		"Prototype claimant connected"
	)


func after_each() -> void:
	for claims: HitClaims in [_client, _server]:
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


func _pair(point: Vector3) -> Array[Zombie]:
	var zombie: Zombie = _server.session.spawner.spawn(WALKER, 1, WAVES)
	zombie.set_physics_process(false)
	zombie.health.reset(1000.0)
	zombie.position = point
	zombie.state = Zombie.State.CHASING
	var path: NodePath = NodePath(String(zombie.name))
	await wait_until(func() -> bool: return _client.session.spawner.has_node(path), 3.0, "Prototype target replicated")
	return [zombie, _client.session.spawner.get_node(path) as Zombie]


func _claim(zombie: Zombie, weapon: WeaponData) -> void:
	_client.claim_hit.rpc_id(1, zombie.name, DamageInfo.Zone.BODY, weapon.damage, weapon.id, zombie.global_position)


func _freeze_neighbour(zombie: Zombie) -> void:
	var info: DamageInfo = DamageInfo.create(CRYO.damage, _claimant)
	info.weapon_id = CRYO.id
	for index: int in Frost.HITS_TO_FREEZE:
		Frost.apply(zombie, info)


func test_client_cryo_claims_freeze_sync_stop_and_shatter_with_one_credited_kill() -> void:
	var pair: Array[Zombie] = await _pair(Vector3(0, 0, -4))
	var cold: Array[Zombie] = await _pair(Vector3(2, 0, -4))
	var warm: Array[Zombie] = await _pair(Vector3(1, 0, -4))
	for count: int in 3:
		_claim(pair[0], CRYO)
		var expected: float = 1000.0 - CRYO.damage * (count + 1)
		await wait_until(func() -> bool: return is_equal_approx(pair[0].health.current, expected), 3.0, "Cryo hit")
		assert_eq(pair[0].frozen, count == 2, "three client hits build a full freeze")
	await wait_until(func() -> bool: return pair[1].frozen, 3.0, "frozen flag replicated")
	var mesh: MeshInstance3D = pair[1].visual.find_children("*", "MeshInstance3D", true, false)[0]
	assert_not_null(mesh.material_overlay, "client shows the synced ice coating")
	_assert_client_cannot_apply_effect(pair)
	_freeze_neighbour(cold[0])
	var position_before: Vector3 = pair[0].global_position
	var clock_before: float = pair[0].state_time
	pair[0].velocity = Vector3(4, 0, 0)
	pair[0].set_physics_process(true)
	await wait_physics_frames(3)
	assert_eq(pair[0].global_position, position_before)
	assert_eq(pair[0].velocity, Vector3.ZERO)
	assert_eq(pair[0].state_time, clock_before, "server AI and attacks remain stopped")
	_claim(pair[0], CRYO)
	await wait_until(func() -> bool: return pair[0].health.is_dead, 3.0, "fourth client hit shattered")
	assert_almost_eq(cold[0].health.current, 1000.0 - CRYO.damage * 0.5, 0.001)
	assert_eq(warm[0].health.current, 1000.0, "unfrozen neighbours receive no shatter damage")
	assert_true(cold[0].frozen, "secondary damage never recursively shatters")
	await wait_until(func() -> bool: return pair[1].state == Zombie.State.DEAD, 3.0, "shatter death synced")
	await _assert_single_kill_credit(pair[0], 5)
	await wait_until(func() -> bool: return _mine.wallet.points == _claimant.wallet.points, 3.0, "owner points synced")
	assert_eq(pair[1].health.current, pair[1].health.max_health, "clients never apply authoritative damage")


func _assert_client_cannot_apply_effect(pair: Array[Zombie]) -> void:
	var info: DamageInfo = DamageInfo.create(CRYO.damage, _mine)
	info.weapon_id = CRYO.id
	var before: float = pair[0].health.current
	assert_false(Frost.apply(pair[1], info), "client-side Frost cannot shatter")
	_client.apply_server_hit(pair[1].hit_zones[1], info)
	assert_eq(pair[0].health.current, before)
	assert_false(pair[0].health.is_dead)


func _assert_single_kill_credit(zombie: Zombie, hits: int) -> void:
	assert_signal_emit_count(Events, "enemy_killed", 1)
	var killed: Array = get_signal_parameters(Events, "enemy_killed")
	assert_eq(killed[0], zombie)
	assert_eq((killed[1] as DamageInfo).attacker, _claimant)
	assert_eq(_progression.get_xp(_claimant), WALKER.xp_reward)
	assert_eq(_progression.get_xp(_host), 0)
	var rewards: ProgressionService = _client.get_parent().get_node("Progression") as ProgressionService
	await wait_until(func() -> bool: return rewards.get_xp(_mine) == WALKER.xp_reward, 3.0, "owner XP synced")
	assert_eq(rewards.get_xp(_mine), WALKER.xp_reward)
	var economy: Economy = _server.get_parent().get_node("Economy") as Economy
	assert_eq(_host.wallet.points, economy.rules.starting_points)
	assert_eq(
		_claimant.wallet.points,
		economy.rules.starting_points + hits * economy.rules.points_per_hit + economy.rules.points_per_kill
	)


func _received_kill(owner: Player) -> bool:
	var count: int = get_signal_emit_count(Events, "hit_confirmed")
	for index: int in maxi(count, 0):
		var parameters: Array = get_signal_parameters(Events, "hit_confirmed", index)
		if parameters == [owner, true, false]:
			return true
	return false


func test_client_synapse_claim_chains_three_server_hits_and_sends_cosmetic_arcs() -> void:
	var source: Array[Zombie] = await _pair(Vector3(0, 0, -4))
	var pairs: Array[Array] = []
	for index: int in 4:
		pairs.append(await _pair(Vector3(index + 1, 0, -4)))
	(pairs[0][0] as Zombie).health.reset(5.0)
	var client_chain: Chain = _client.get_node("Chain") as Chain
	watch_signals(client_chain)
	_claim(source[0], SYNAPSE)
	await wait_until(func() -> bool: return source[0].health.current < 1000.0, 3.0, "Synapse primary applied")
	assert_almost_eq(source[0].health.current, 1000.0 - SYNAPSE.damage, 0.001)
	assert_true((pairs[0][0] as Zombie).health.is_dead)
	for index: int in [1, 2]:
		assert_almost_eq((pairs[index][0] as Zombie).health.current, 1000.0 - SYNAPSE.damage * 0.5, 0.001)
	assert_eq((pairs[3][0] as Zombie).health.current, 1000.0, "chain stops at three distinct neighbours")
	await wait_until(
		func() -> bool: return get_signal_emit_count(client_chain, "child_entered_tree") == 3, 3.0, "three client arcs"
	)
	assert_signal_emit_count(client_chain, "child_entered_tree", 3)
	await _assert_single_kill_credit(pairs[0][0] as Zombie, 4)
	await wait_until(func() -> bool: return _received_kill(_mine), 3.0, "chain kill confirmation reached the owner")
	assert_true(_received_kill(_mine), "the owning client's Player receives a reliable secondary kill confirmation")
	assert_false(source[0].health.is_dead, "the client kill marker belongs to a secondary kill")
	for pair: Array in pairs:
		var copy: Zombie = pair[1] as Zombie
		assert_eq(copy.health.current, copy.health.max_health, "arc RPCs never change client health")

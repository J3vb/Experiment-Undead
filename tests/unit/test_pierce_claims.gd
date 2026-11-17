## Piercing shots use C3's real owner claims, server rewards and one cosmetic endpoint per pellet.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const WAVES: WaveRules = preload("res://content/waves/default_waves.tres")
const IRONWOOD: WeaponData = preload("res://content/weapons/ironwood_50.tres")
const PORT: int = 24692

var server: HitClaims
var client: HitClaims
var claimant: Player
var host: Player
var mine: Player
var progression: ProgressionService
var _servers: Array[Zombie] = []
var _clients: Array[Zombie] = []


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
	session.spawner.spawn_group = &"test_pierce_claim_points"
	session.spawner.session = session
	root.add_child(session.spawner)
	session.hit_claims = HitClaims.new()
	session.hit_claims.name = "HitClaims"
	session.hit_claims.session = session
	root.add_child(session.hit_claims)
	session.remote_shots = RemoteShots.new()
	session.remote_shots.name = "RemoteShots"
	session.remote_shots.session = session
	root.add_child(session.remote_shots)
	session.players = PlayerSpawner.new()
	session.players.name = "PlayerSpawner"
	session.players.player_scene = PLAYER
	session.players.player_added.connect(_prepare_player.bind(session))
	root.add_child(session.players)
	return session.hit_claims


func _prepare_player(player: Player, session: GameSession) -> void:
	var data: WeaponData = IRONWOOD.duplicate() as WeaponData
	data.hip_spread = 0.0
	data.ads_spread = 0.0
	data.recoil = null
	data.viewmodel_scene = null
	player.spawn(session, [data])
	player.set_physics_process(false)
	player.input_enabled = false
	session.remote_shots.watch_player(player)


func before_each() -> void:
	server = _make_side("Server")
	client = _make_side("Client")
	progression = server.get_parent().get_node("Progression") as ProgressionService
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_pierce_claim_points")
	marker.position = Vector3(0, 0, -4)
	server.get_parent().add_child(marker)
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT, 2), OK)
	server.multiplayer.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client.multiplayer.multiplayer_peer = client_peer
	client.session.players.setup(client.get_parent().get_node("World") as Node3D, Transform3D.IDENTITY)
	server.session.players.setup(server.get_parent().get_node("World") as Node3D, Transform3D.IDENTITY)
	await wait_until(_players_connected, 5.0, "two peers have their players")
	var peer_id: int = client.multiplayer.get_unique_id()
	claimant = server.session.players.find_player(peer_id)
	host = server.session.players.find_player(1)
	mine = client.session.players.find_player(peer_id)
	mine.camera.global_position = Vector3(0, 0.8, 0)
	mine.camera.global_basis = Basis.IDENTITY
	server.set_physics_process(false)
	watch_signals(Events)
	watch_signals(mine.weapons.current)


func _players_connected() -> bool:
	var peer_id: int = client.multiplayer.get_unique_id()
	return (
		peer_id > 1
		and server.session.players.find_player(peer_id) != null
		and client.session.players.find_player(peer_id) != null
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
	_servers.clear()
	_clients.clear()


func _line(health: float = 1000.0) -> void:
	for index: int in 3:
		var zombie: Zombie = server.session.spawner.spawn(WALKER, 1, WAVES)
		zombie.set_physics_process(false)
		zombie.position = Vector3(0, 0, -4.0 - index * 3.0)
		zombie.rotation = Vector3.ZERO
		zombie.health.reset(health)
		for zone: HitZone in zombie.hit_zones:
			zone.set_enabled(false)
		var path: NodePath = NodePath(String(zombie.name))
		await wait_until(func() -> bool: return client.session.spawner.has_node(path), 3.0, "zombie replicated")
		var copy: Zombie = client.session.spawner.get_node(path) as Zombie
		copy.position = zombie.position
		copy.rotation = Vector3.ZERO
		copy.set_physics_process(false)
		copy.head_zone.set_enabled(false)
		_servers.append(zombie)
		_clients.append(copy)
	await wait_physics_frames(2)


func _fire_as_client() -> void:
	# The isolated peer trees share one Net autoload; select the firing peer for this synchronous call.
	var previous: MultiplayerPeer = Net.multiplayer.multiplayer_peer
	Net.multiplayer.multiplayer_peer = client.multiplayer.multiplayer_peer
	assert_false(Net.is_authority())
	mine.weapons.current.fire()
	Net.multiplayer.multiplayer_peer = previous


func _flush_claims() -> void:
	await wait_physics_frames(8)


func _assert_line_damage(shots: int) -> void:
	for index: int in 3:
		var damage: float = IRONWOOD.damage * pow(0.8, index) * shots
		assert_almost_eq(_servers[index].health.current, 1000.0 - damage, 0.001, "server hit %d" % index)
		assert_eq(_clients[index].health.current, 100.0, "claims leave client health untouched")


func test_client_fire_claims_three_pierced_hits_with_normal_damage_decay() -> void:
	await _line()
	var before_owner: int = claimant.wallet.points
	var before_host: int = host.wallet.points
	_fire_as_client()
	assert_signal_emit_count(mine.weapons.current, "hit_landed", 3, "every local hit has immediate feedback")
	for zombie: Zombie in _clients:
		assert_eq(zombie.health.current, 100.0, "local firing never directly applies damage")
	await _flush_claims()
	_assert_line_damage(1)
	assert_eq(claimant.wallet.points, before_owner + 30, "all three hits reward the claiming player")
	assert_eq(host.wallet.points, before_host)
	assert_signal_emit_count(Events, "enemy_damaged", 3)
	var damage: DamageInfo = get_signal_parameters(Events, "enemy_damaged")[1] as DamageInfo
	assert_eq(damage.attacker, claimant)


func test_two_ironwood_shots_at_normal_cadence_keep_all_six_claims() -> void:
	await _line()
	assert_almost_eq(IRONWOOD.get_fire_interval(), 0.75, 0.001)
	var before: int = claimant.wallet.points
	_fire_as_client()
	await _flush_claims()
	server._physics_process(0.75)
	_fire_as_client()
	await _flush_claims()
	_assert_line_damage(2)
	assert_eq(claimant.wallet.points, before + 60, "the second shot retains all three hits")
	assert_signal_emit_count(Events, "enemy_damaged", 6)


func test_piercing_kills_credit_the_claimant_and_sync_its_points() -> void:
	await _line(100.0)
	var before_owner: int = claimant.wallet.points
	var before_host: int = host.wallet.points
	_fire_as_client()
	await _flush_claims()
	for index: int in 3:
		assert_true(_servers[index].health.is_dead)
		assert_eq(_clients[index].health.current, 100.0)
	assert_signal_emit_count(Events, "enemy_killed", 3)
	var killed: DamageInfo = get_signal_parameters(Events, "enemy_killed")[1] as DamageInfo
	assert_eq(killed.attacker, claimant)
	assert_eq(claimant.wallet.points, before_owner + 210, "three body kills and their hit rewards")
	assert_eq(mine.wallet.points, claimant.wallet.points)
	assert_eq(host.wallet.points, before_host)
	assert_eq(progression.get_xp(claimant), WALKER.xp_reward * 3)
	assert_eq(progression.get_xp(host), 0)


func test_remote_shot_uses_one_final_endpoint_for_the_piercing_pellet() -> void:
	await _line()
	var points: Array[Vector3] = []
	mine.weapons.current.traced.connect(
		func(point: Vector3, _normal: Vector3, _flesh: bool) -> void: points.append(point)
	)
	var effects: RemoteShotEffects = claimant.get_node("ShotEffects") as RemoteShotEffects
	_fire_as_client()
	assert_eq(points.size(), 3, "local impacts still report all pierced zombies")
	await wait_until(func() -> bool: return _drawn(effects), 3.0, "server renders the shot")
	var tracers: Array[Node] = effects.find_children("Tracers*", "MeshInstance3D", false, false)
	assert_eq(tracers.size(), 1, "one cosmetic packet renders one shot")
	if tracers.size() != 1:
		return
	var mesh: Mesh = (tracers[0] as MeshInstance3D).mesh
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(vertices.size(), IRONWOOD.pellets * 2, "piercing keeps one endpoint per pellet")
	assert_almost_eq(vertices[-1].distance_to(points[-1]), 0.0, 0.001, "tracer ends at the final pierced hit")
	assert_true(client.session.remote_shots._points.is_empty(), "firing flushes the cosmetic endpoints")


func _drawn(effects: RemoteShotEffects) -> bool:
	var tracers: Node3D = effects.get_node_or_null("Tracers") as Node3D
	return tracers != null and tracers.visible

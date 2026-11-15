## Real client traces claim every shotgun pellet over ENet. Only the server
## zombie loses health and receives the validated both-barrel impulse.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const WAVES: WaveRules = preload("res://content/waves/default_waves.tres")
const PORT: int = 24683

var server: HitClaims
var client: HitClaims
var claimant: Player
var mine: Player
var zombie: Zombie
var copy: Zombie
var damage_events: Array[DamageInfo] = []


func _make_side(side_name: String) -> HitClaims:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var session: GameSession = GameSession.new()
	session.rng.seed = 17
	var world: Node3D = Node3D.new()
	world.name = "World"
	root.add_child(world)
	session.spawner = Spawner.new()
	session.spawner.name = "Enemies"
	session.spawner.spawn_group = &"test_double_barrel_claim_points"
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
	session.hit_claims = claims
	root.add_child(claims)
	return claims


func _prepare_player(player: Player, session: GameSession) -> void:
	player.spawn(session, [Content.weapon(&"rifle_ar")])
	player.set_physics_process(false)
	player.input_enabled = false


func before_each() -> void:
	damage_events.clear()
	server = _make_side("Server")
	client = _make_side("Client")
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_double_barrel_claim_points")
	marker.position = Vector3(0, 0, -4)
	server.get_parent().add_child(marker)
	await _connect_peers()
	var peer_id: int = client.multiplayer.get_unique_id()
	claimant = server.session.players.find_player(peer_id)
	mine = client.session.players.find_player(peer_id)
	await _spawn_target()


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


func _spawn_target() -> void:
	zombie = server.session.spawner.spawn(WALKER, 1, WAVES)
	zombie.set_physics_process(false)
	zombie.health.reset(10000.0)
	zombie.health.damaged.connect(func(info: DamageInfo) -> void: damage_events.append(info))
	var path: NodePath = NodePath(String(zombie.name))
	await wait_until(func() -> bool: return client.session.spawner.has_node(path), 3.0, "zombie replicated")
	copy = client.session.spawner.get_node(path) as Zombie
	for zone: HitZone in zombie.hit_zones:
		zone.set_enabled(false)
	copy.head_zone.set_enabled(false)
	var body: HitZone = copy.hit_zones[1]
	mine.camera.global_position = body.global_position + Vector3(0, 0, 2)
	await wait_physics_frames(2)


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


func _gun(id: StringName) -> Weapon:
	var data: WeaponData = Content.weapon(id).duplicate() as WeaponData
	data.hip_spread = 0.0
	data.ads_spread = 0.0
	data.recoil = null
	data.viewmodel_scene = null
	data.fire_sound = null
	mine.weapons.replace_current(data)
	mine.input_enabled = true
	var weapon: Weapon = mine.weapons.current
	weapon.instance.ammo_reserve = 0
	watch_signals(weapon)
	return weapon


func _shoot(weapon: Weapon, alt: bool) -> void:
	# Net is an autoload outside both test subtrees. Route only this synchronous
	# client tick through its peer, then restore the server role before RPC polling.
	var original_peer: MultiplayerPeer = Net.multiplayer.multiplayer_peer
	Net.multiplayer.multiplayer_peer = client.multiplayer.multiplayer_peer
	mine.last_frame.buttons = DoubleBarrel.ALT_FIRE if alt else 0
	weapon.trigger_held = not alt
	weapon.tick(1.0 / 60.0)
	Net.multiplayer.multiplayer_peer = original_peer


func _assert_receipts(count: int, impulse: Vector3) -> void:
	await wait_until(func() -> bool: return damage_events.size() == count, 3.0, "server received every pellet")
	assert_eq(damage_events.size(), count)
	for info: DamageInfo in damage_events:
		assert_eq(info.attacker, claimant, "server resolves the owning client as attacker")
		assert_eq(info.impulse, impulse, "impulse survives the normal trace and claim RPC")


func test_coachman_client_alt_fire_claims_twenty_knockback_pellets() -> void:
	var weapon: Weapon = _gun(&"coachman_2b")
	var client_health: float = copy.health.current
	_shoot(weapon, true)
	assert_eq(weapon.instance.ammo_in_mag, 0)
	assert_signal_emit_count(weapon, "fired", 1)
	await _assert_receipts(20, Vector3(0, 0, -8))
	assert_almost_eq(zombie.health.current, 10000.0 - weapon.data.damage * 20, 0.01)
	assert_eq(zombie.velocity, Vector3(0, 0, -8), "twenty pellets produce one bounded shove")
	await wait_until(func() -> bool: return copy.velocity == Vector3(0, 0, -8), 3.0, "knockback synced")
	assert_eq(copy.velocity, zombie.velocity, "the client observes the server-owned knockback")
	assert_eq(copy.health.current, client_health, "the client never applies claimed damage locally")
	assert_false(zombie.health.is_dead)
	var before: float = zombie.position.z
	zombie.state = Zombie.State.ATTACKING
	zombie.state_time = 0.0
	zombie.set_physics_process(true)
	await wait_physics_frames(3)
	zombie.set_physics_process(false)
	assert_lt(zombie.position.z, before - 0.1, "the server body actually moves away after the blast")


func test_grubber_client_alt_fire_claims_sixteen_knockback_pellets() -> void:
	var weapon: Weapon = _gun(&"grubber_sawnoff")
	var client_health: float = copy.health.current
	_shoot(weapon, true)
	assert_eq(weapon.instance.ammo_in_mag, 0)
	assert_signal_emit_count(weapon, "fired", 1)
	await _assert_receipts(16, Vector3(0, 0, -8))
	assert_almost_eq(zombie.health.current, 10000.0 - weapon.data.damage * 16, 0.01)
	assert_eq(zombie.velocity, Vector3(0, 0, -8), "sixteen pellets do not accumulate sixteen impulses")
	await wait_until(func() -> bool: return copy.velocity == Vector3(0, 0, -8), 3.0, "knockback synced")
	assert_eq(copy.velocity, zombie.velocity, "the client observes the server-owned knockback")
	assert_eq(copy.health.current, client_health)
	assert_false(zombie.health.is_dead)


func test_primary_and_single_round_client_fallback_keep_normal_impulse() -> void:
	var weapon: Weapon = _gun(&"coachman_2b")
	var client_health: float = copy.health.current
	_shoot(weapon, false)
	assert_eq(weapon.instance.ammo_in_mag, 1)
	await _assert_receipts(10, Vector3(0, 0, -2))
	assert_eq(zombie.velocity, Vector3.ZERO, "normal impacts only flinch the visual")
	damage_events.clear()
	weapon = _gun(&"coachman_2b")
	weapon.instance.ammo_in_mag = 1
	_shoot(weapon, true)
	assert_eq(weapon.instance.ammo_in_mag, 0)
	await _assert_receipts(10, Vector3(0, 0, -2))
	assert_eq(zombie.velocity, Vector3.ZERO, "one-round fallback cannot apply both-barrel knockback")
	assert_eq(copy.health.current, client_health)


func test_claims_reject_excessive_and_nonfinite_impulses() -> void:
	var point: Vector3 = copy.hit_zones[1].global_position
	for impulse: Vector3 in [Vector3(0, 0, -100), Vector3(NAN, 0, 0), Vector3(0, INF, 0)]:
		client.claim_hit.rpc_id(1, zombie.name, DamageInfo.Zone.BODY, 1.0, &"coachman_2b", point, impulse)
	await wait_physics_frames(8)
	assert_eq(zombie.health.current, 10000.0)
	assert_eq(damage_events.size(), 0, "bad impulse claims never damage the server zombie")
	client.claim_hit.rpc_id(1, zombie.name, DamageInfo.Zone.BODY, 1.0, &"coachman_2b", point, Vector3(0, 0, -8))
	await _assert_receipts(1, Vector3(0, 0, -8))
	assert_eq(zombie.health.current, 9999.0, "a valid shotgun impulse still works")


func test_normal_non_axis_impulse_preserves_zombie_movement() -> void:
	var movement: Vector3 = Vector3(1.9, 0, 0)
	zombie.velocity = movement
	var impulse: Vector3 = Vector3(0.0006, 0.006, -1.0).normalized() * 2.0
	client.claim_hit.rpc_id(1, zombie.name, DamageInfo.Zone.BODY, 1.0, &"coachman_2b", copy.position, impulse)
	await _assert_receipts(1, impulse)
	assert_eq(zombie.velocity, movement, "floating-point normal flinches cannot replace movement")

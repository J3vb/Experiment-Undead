## Synapse chooses unique nearby living zombies, preserves attribution and only
## lets the server apply damage; its remote arc is cosmetic.
extends GutTest

const WALKER: String = "res://content/enemies/zombie_walker.tres"
const RULES: String = "res://content/waves/default_waves.tres"
const PORT: int = 24669

var _session: GameSession
var _spawner: Spawner
var _chain: Chain


func before_each() -> void:
	_session = GameSession.new()
	_session.rng.seed = 17
	_spawner = Spawner.new()
	_spawner.session = _session
	_spawner.spawn_group = &"test_chain_spawn"
	add_child(_spawner)
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_chain_spawn")
	_spawner.add_child(marker)
	_chain = Chain.new()
	add_child(_chain)


func after_each() -> void:
	_chain.free()
	_spawner.free()
	_session.free()


func _zombie(point: Vector3) -> Zombie:
	var zombie: Zombie = _spawner.spawn(load(WALKER) as EnemyData, 1, load(RULES) as WaveRules)
	zombie.set_physics_process(false)
	zombie.position = point
	zombie.health.reset(1000.0)
	return zombie


func _hit(amount: float = 40.0) -> DamageInfo:
	var info: DamageInfo = DamageInfo.create(amount, self)
	info.weapon_id = &"synapse"
	return info


func test_chains_to_at_most_three_unique_nearby_zombies() -> void:
	var source: Zombie = _zombie(Vector3.ZERO)
	var targets: Array[Zombie] = []
	for i: int in 5:
		targets.append(_zombie(Vector3(i + 1.0, 0, 0)))
	_chain.apply(source, _hit())
	assert_eq(source.health.current, 1000.0, "the primary path owns primary damage")
	for i: int in targets.size():
		assert_eq(targets[i].health.current, 980.0 if i < 3 else 1000.0)
	assert_eq(_chain.get_child_count(), 3, "one cosmetic arc per secondary hit")


func test_range_includes_six_metres_but_not_beyond() -> void:
	var source: Zombie = _zombie(Vector3.ZERO)
	var inside: Zombie = _zombie(Vector3(0, 0, 6))
	var outside: Zombie = _zombie(Vector3(0, 0, 6.01))
	_chain.apply(source, _hit())
	assert_eq(inside.health.current, 980.0)
	assert_eq(outside.health.current, 1000.0)


func test_half_damage_keeps_attacker_and_weapon_without_headshot_multiplier() -> void:
	var source: Zombie = _zombie(Vector3.ZERO)
	var target: Zombie = _zombie(Vector3.ONE)
	watch_signals(target.health)
	var info: DamageInfo = _hit(80.0)
	info.hit_zone = DamageInfo.Zone.HEAD
	_chain.apply(source, info)
	assert_eq(target.health.current, 960.0)
	var received: DamageInfo = get_signal_parameters(target.health, "damaged")[0] as DamageInfo
	assert_eq(received.attacker, self)
	assert_eq(received.weapon_id, &"synapse")
	assert_eq(received.hit_zone, DamageInfo.Zone.BODY)
	assert_eq(info.amount, 80.0, "secondary hits leave the primary DamageInfo unchanged")


func test_dead_targets_are_skipped_and_dead_source_cannot_chain() -> void:
	var source: Zombie = _zombie(Vector3.ZERO)
	var dead: Zombie = _zombie(Vector3.ONE)
	var living: Zombie = _zombie(Vector3(2, 0, 0))
	dead.health.take_damage(_hit(1000.0))
	_chain.apply(source, _hit())
	assert_eq(living.health.current, 980.0)
	source.health.take_damage(_hit(1000.0))
	_chain.apply(source, _hit())
	assert_eq(living.health.current, 980.0)


func test_nearby_zombie_in_other_spawner_is_not_hit() -> void:
	var source: Zombie = _zombie(Vector3.ZERO)
	var other: Node3D = Node3D.new()
	add_child(other)
	var outside_match: Zombie = _zombie(Vector3.ONE)
	outside_match.reparent(other)
	_chain.apply(source, _hit())
	assert_eq(outside_match.health.current, 1000.0)
	other.free()


func test_two_peers_receive_cosmetic_arcs_without_client_damage() -> void:
	var server_root: Node = _side("Server")
	var client_root: Node = _side("Client")
	var server_chain: Chain = server_root.get_node("Chain") as Chain
	var client_chain: Chain = client_root.get_node("Chain") as Chain
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT, 2), OK)
	server_root.multiplayer.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client_root.multiplayer.multiplayer_peer = client_peer
	await wait_until(
		func() -> bool:
			return client_root.multiplayer.get_unique_id() > 1 and server_root.multiplayer.get_peers().size() == 1,
		3.0,
		"connected"
	)
	var source: Zombie = _zombie(Vector3.ZERO)
	var target: Zombie = _zombie(Vector3.ONE)
	client_chain.apply(source, _hit())
	assert_eq(target.health.current, 1000.0, "clients cannot deal chain damage")
	server_chain.apply(source, _hit())
	await wait_until(func() -> bool: return client_chain.get_child_count() == 1, 3.0, "arc reached client")
	assert_eq(target.health.current, 980.0, "only the server applied one half-damage hit")
	assert_eq(client_chain.get_child_count(), 1)
	assert_eq((client_chain.get_child(0) as Node3D).global_position, Vector3.UP)
	_close_side(client_root)
	_close_side(server_root)


func _side(side_name: String) -> Node:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	root.add_child(Chain.new())
	return root


func _close_side(root: Node) -> void:
	var path: NodePath = root.get_path()
	root.multiplayer.multiplayer_peer.close()
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	root.free()
	get_tree().set_multiplayer(null, path)

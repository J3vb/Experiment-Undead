## Synapse chooses unique nearby living zombies, preserves attribution and only
## lets the server apply damage; its remote arc is cosmetic.
extends GutTest

const WALKER: String = "res://content/enemies/zombie_walker.tres"
const RULES: String = "res://content/waves/default_waves.tres"

var _port: int
var _session: GameSession
var _spawner: Spawner
var _chain: Chain


func before_each() -> void:
	_port = TwoPeers.next_port()
	_session = CoopSide.make(self, "Match")
	_session.rng.seed = 17
	_spawner = _session.spawner
	CoopSide.add_spawn_point(_session)
	_chain = Chain.new()
	add_child(_chain)


func after_each() -> void:
	_chain.free()
	CoopSide.close(_session)


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
	assert_eq(TwoPeers.host(server_root, _port, 2), OK)
	assert_eq(TwoPeers.join(client_root, _port), OK)
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
	TwoPeers.close_side(client_root)
	TwoPeers.close_side(server_root)


func _side(side_name: String) -> Node:
	var root: Node = TwoPeers.make_side(self, side_name)
	root.add_child(Chain.new())
	return root


func test_arc_segments_share_one_mesh_scaled_to_length() -> void:
	_chain.show_arcs(Vector3.ZERO, PackedVector3Array([Vector3(3, 0, 0), Vector3(0, 0, 4)]))
	var segments: Array[Node] = _chain.find_children("*", "MeshInstance3D", true, false)
	assert_eq(segments.size(), 6, "two arcs of three segments")
	var first: MeshInstance3D = segments[0] as MeshInstance3D
	for node: Node in segments:
		assert_same((node as MeshInstance3D).mesh, first.mesh)
	var side: Vector3 = Vector3(3, 0, 0).cross(Vector3.UP).normalized() * 0.12
	var expected: float = (Vector3(3, 0, 0) * 0.33 + side).length()
	assert_almost_eq(first.scale.y, expected, 0.001)
	assert_almost_eq((first.mesh as CylinderMesh).height, 1.0, 0.001)

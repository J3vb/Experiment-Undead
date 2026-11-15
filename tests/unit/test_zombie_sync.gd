## Two peers in one process: zombies made by the server's Spawner appear on
## the client with the same name, follow the server's pose and state, run no
## AI there, show their death and vanish when the server frees them.
extends GutTest

const WALKER: String = "res://content/enemies/zombie_walker.tres"
const RULES: String = "res://content/waves/default_waves.tres"
const PORT: int = 24661

var server_root: Node
var client_root: Node
var server_spawner: Spawner
var client_spawner: Spawner
var _session: GameSession


func _make_side(side_name: String) -> Spawner:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var spawner: Spawner = Spawner.new()
	spawner.name = "Enemies"
	spawner.spawn_group = &"test_zombie_sync_points"
	spawner.session = _session
	root.add_child(spawner)
	return spawner


func before_each() -> void:
	_session = GameSession.new()
	_session.rng.seed = 7
	server_spawner = _make_side("Server")
	client_spawner = _make_side("Client")
	server_root = server_spawner.get_parent()
	client_root = client_spawner.get_parent()
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_zombie_sync_points")
	marker.position = Vector3(4, 0, -3)
	server_root.add_child(marker)
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT, 2), OK)
	server_root.multiplayer.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client_root.multiplayer.multiplayer_peer = client_peer
	await wait_until(
		func() -> bool:
			return client_root.multiplayer.get_unique_id() > 1 and server_root.multiplayer.get_peers().size() == 1,
		5.0,
		"connected"
	)


func after_each() -> void:
	for root: Node in [client_root, server_root]:
		var path: NodePath = root.get_path()
		root.multiplayer.multiplayer_peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		for child: Node in (root.get_node("Enemies") as Node).get_children():
			if child is Zombie:
				child.free()
		root.free()
		get_tree().set_multiplayer(null, path)
	_session.free()


func _spawn_on_server() -> Array[Zombie]:
	var zombie: Zombie = server_spawner.spawn(load(WALKER) as EnemyData, 1, load(RULES) as WaveRules)
	var copy_path: NodePath = NodePath(String(zombie.name))
	await wait_until(func() -> bool: return client_spawner.has_node(copy_path), 3.0, "zombie reached client")
	return [zombie, client_spawner.get_node_or_null(copy_path) as Zombie]


func test_client_copy_follows_the_server_zombie() -> void:
	var pair: Array[Zombie] = await _spawn_on_server()
	var zombie: Zombie = pair[0]
	var copy: Zombie = pair[1]
	assert_not_null(copy)
	if copy == null:
		return
	assert_eq(copy.net_id, zombie.net_id)
	assert_eq(copy.data.resource_path, WALKER)
	assert_false(copy.is_physics_processing(), "clients run no zombie AI")
	assert_true(zombie.is_physics_processing(), "the server runs the AI")
	zombie.set_physics_process(false)
	zombie.position = Vector3(10, 2, 6)
	zombie.rotation.y = 0.8
	zombie.state = Zombie.State.CHASING
	zombie.velocity = Vector3(1.5, 0, 0)
	await wait_until(func() -> bool: return copy.position.is_equal_approx(zombie.position), 3.0, "pose synced")
	assert_almost_eq(copy.rotation.y, 0.8, 0.001)
	assert_eq(copy.state, Zombie.State.CHASING)
	assert_eq(copy.velocity, Vector3(1.5, 0, 0))


func test_death_shows_on_client_and_free_despawns() -> void:
	var pair: Array[Zombie] = await _spawn_on_server()
	var zombie: Zombie = pair[0]
	var copy: Zombie = pair[1]
	var info: DamageInfo = DamageInfo.new()
	info.amount = 100000.0
	zombie.health.take_damage(info)
	assert_eq(zombie.state, Zombie.State.DEAD)
	await wait_until(func() -> bool: return copy.collision_layer == 0, 3.0, "client shows the death")
	assert_eq(copy.state, Zombie.State.DEAD)
	assert_eq(copy.head_zone.collision_layer, 0, "dead zombies cannot be shot on the client")
	var copy_name: StringName = copy.name
	zombie.queue_free()
	await wait_until(func() -> bool: return not client_spawner.has_node(NodePath(String(copy_name))), 3.0, "despawned")
	assert_false(client_spawner.has_node(NodePath(String(copy_name))))

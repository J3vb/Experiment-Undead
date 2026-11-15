## Two peers in one process (each subtree has its own SceneMultiplayer over
## ENet on localhost): one player per peer, owned by that peer, and each
## owner's pose reaches the other side.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const PORT: int = 24641

var server_root: Node
var client_root: Node
var server_spawner: PlayerSpawner
var client_spawner: PlayerSpawner


func _make_side(side_name: String) -> Node:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var world: Node3D = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var spawner: PlayerSpawner = PlayerSpawner.new()
	spawner.name = "PlayerSpawner"
	spawner.player_scene = PLAYER
	root.add_child(spawner)
	return root


func before_each() -> void:
	server_root = _make_side("Server")
	client_root = _make_side("Client")
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT, 2), OK)
	server_root.multiplayer.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client_root.multiplayer.multiplayer_peer = client_peer
	server_spawner = server_root.get_node("PlayerSpawner") as PlayerSpawner
	client_spawner = client_root.get_node("PlayerSpawner") as PlayerSpawner
	var spawn_point: Transform3D = Transform3D(Basis(), Vector3(5, 0, 5))
	client_spawner.setup(client_root.get_node("World") as Node3D, spawn_point)
	server_spawner.setup(server_root.get_node("World") as Node3D, spawn_point)


func after_each() -> void:
	for root: Node in [client_root, server_root]:
		var path: NodePath = root.get_path()
		root.multiplayer.multiplayer_peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		for player: Player in _players(root):
			player.free()
		root.free()
		get_tree().set_multiplayer(null, path)


func _players(root: Node) -> Array[Player]:
	var out: Array[Player] = []
	for child: Node in root.get_node("World").get_children():
		if child is Player:
			out.append(child as Player)
	return out


func _wait_for_two_players() -> void:
	var ready: Callable = func() -> bool: return _players(server_root).size() == 2 and _players(client_root).size() == 2
	await wait_until(ready, 5.0, "both peers see two players")


func test_each_peer_gets_a_player_it_owns() -> void:
	await _wait_for_two_players()
	var client_id: int = client_root.multiplayer.get_unique_id()
	var mine: Player = client_spawner.find_player(client_id)
	var host: Player = client_spawner.find_player(1)
	assert_not_null(mine)
	assert_not_null(host)
	assert_true(mine.is_multiplayer_authority())
	assert_false(host.is_multiplayer_authority())
	assert_eq(mine.net_id, client_id)
	assert_true(mine.camera.current)
	var geometry: GeometryInstance3D = mine.body.find_children("*", "GeometryInstance3D", true, false)[0]
	assert_eq(geometry.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	assert_eq(geometry.layers, 1, "owner stays on the world layer so its shadow is rendered")
	var remote_geometry: GeometryInstance3D = host.body.find_children("*", "GeometryInstance3D", true, false)[0]
	assert_eq(remote_geometry.layers, 1)
	assert_eq(remote_geometry.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert_true(host.body.visible, "other players show a body")
	assert_false(host.weapons.visible, "other players hide their first-person gun")
	assert_false(host.is_physics_processing(), "only the owner simulates its player")
	assert_ne(mine.position, host.position, "players spawn side by side")


func test_owner_pose_reaches_the_other_peer() -> void:
	await _wait_for_two_players()
	var client_id: int = client_root.multiplayer.get_unique_id()
	var mine: Player = client_spawner.find_player(client_id)
	var host: Player = server_spawner.find_player(1)
	mine.set_physics_process(false)
	host.set_physics_process(false)
	mine.position = Vector3(3, 1, -7)
	mine.rotation.y = 1.25
	mine.camera_rig.rotation.x = -0.4
	host.position = Vector3(-2, 0, 4)
	var mine_on_server: Player = server_spawner.find_player(client_id)
	var host_on_client: Player = client_spawner.find_player(1)
	await wait_until(func() -> bool: return mine_on_server.position.is_equal_approx(mine.position), 3.0, "client pose")
	await wait_until(func() -> bool: return host_on_client.position.is_equal_approx(host.position), 3.0, "host pose")
	assert_almost_eq(mine_on_server.rotation.y, 1.25, 0.001)
	assert_almost_eq(mine_on_server.camera_rig.rotation.x, -0.4, 0.001)
	assert_true(host_on_client.position.is_equal_approx(Vector3(-2, 0, 4)))


func test_leaving_peer_loses_its_player() -> void:
	await _wait_for_two_players()
	var client_id: int = client_root.multiplayer.get_unique_id()
	assert_null(server_spawner.add_peer(client_id), "a peer never gets a second player")
	client_root.multiplayer.multiplayer_peer.close()
	await wait_until(func() -> bool: return server_spawner.find_player(client_id) == null, 5.0, "player removed")
	assert_null(server_spawner.find_player(client_id))
	assert_eq(_players(server_root).size(), 1, "the host keeps its own player")

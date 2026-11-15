## Real ENet peers authenticate before player replication; incompatible or full joins explain their refusal.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const PORT: int = 24662

var server_root: Node
var client_root: Node
var server_handshake: Handshake
var client_handshake: Handshake
var server_spawner: PlayerSpawner
var _sides: Array[Node] = []


func _make_side(side_name: String) -> Node:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	_sides.append(root)
	var world: Node3D = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var handshake: Handshake = Handshake.new()
	handshake.name = "Handshake"
	root.add_child(handshake)
	var spawner: PlayerSpawner = PlayerSpawner.new()
	spawner.name = "PlayerSpawner"
	spawner.player_scene = PLAYER
	spawner.player_added.connect(func(player: Player) -> void: player.set_physics_process(false))
	root.add_child(spawner)
	return root


func before_each() -> void:
	server_root = _make_side("HandshakeServer")
	client_root = _make_side("HandshakeClient")
	server_handshake = server_root.get_node("Handshake") as Handshake
	client_handshake = client_root.get_node("Handshake") as Handshake
	server_spawner = server_root.get_node("PlayerSpawner") as PlayerSpawner
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_server(PORT, Net.MAX_PLAYERS + 1), OK)
	server_root.multiplayer.multiplayer_peer = peer
	server_handshake.setup("Host", 12)
	server_spawner.setup(server_root.get_node("World") as Node3D, Transform3D.IDENTITY)
	watch_signals(server_handshake)
	watch_signals(client_handshake)


func after_each() -> void:
	_sides.reverse()
	for root: Node in _sides:
		var path: NodePath = root.get_path()
		root.multiplayer.multiplayer_peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		root.free()
		get_tree().set_multiplayer(null, path)
	_sides.clear()


func _join(root: Node) -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", PORT), OK)
	root.multiplayer.multiplayer_peer = peer
	var handshake: Handshake = root.get_node("Handshake") as Handshake
	handshake.setup("Client", 7)
	var spawner: PlayerSpawner = root.get_node("PlayerSpawner") as PlayerSpawner
	spawner.setup(root.get_node("World") as Node3D, Transform3D.IDENTITY)


func _player_count(root: Node) -> int:
	var count: int = 0
	for child: Node in root.get_node("World").get_children():
		if child is Player:
			count += 1
	return count


func _assert_refused(reason: Net.RefusalReason) -> void:
	await wait_until(func() -> bool: return client_handshake.refusal_reason == reason, 5.0, "reason received")
	assert_eq(client_handshake.refusal_reason, reason)
	assert_signal_emitted(client_handshake, "refused")
	var peer: MultiplayerPeer = client_root.multiplayer.multiplayer_peer
	await wait_until(
		func() -> bool: return peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED,
		5.0,
		"refused peer disconnected"
	)
	assert_eq(_player_count(client_root), 0, "refused clients never receive any Player")
	assert_eq(_player_count(server_root), 1, "the refused peer never gets a Player on the server")
	assert_signal_not_emitted(server_handshake, "accepted")


func test_matching_hello_spawns_the_player_on_both_peers() -> void:
	_join(client_root)
	await wait_until(
		func() -> bool: return _player_count(server_root) == 2 and _player_count(client_root) == 2,
		5.0,
		"matching client spawned"
	)
	var peer_id: int = client_root.multiplayer.get_unique_id()
	assert_not_null(server_spawner.find_player(peer_id))
	var client_spawner: PlayerSpawner = client_root.get_node("PlayerSpawner") as PlayerSpawner
	assert_not_null(client_spawner.find_player(peer_id))
	assert_signal_emitted_with_parameters(server_handshake, "accepted", [peer_id])
	assert_signal_not_emitted(client_handshake, "refused")


func test_wrong_protocol_is_refused_with_both_versions_without_spawning() -> void:
	client_handshake.protocol_version = Build.PROTOCOL_VERSION + 17
	_join(client_root)
	await _assert_refused(Net.RefusalReason.WRONG_VERSION)
	assert_signal_emitted_with_parameters(
		client_handshake,
		"refused",
		[Net.RefusalReason.WRONG_VERSION, Build.PROTOCOL_VERSION + 17, Build.PROTOCOL_VERSION]
	)
	assert_true(client_handshake.refusal_message.contains(str(Build.PROTOCOL_VERSION + 17)))
	assert_true(client_handshake.refusal_message.contains(str(Build.PROTOCOL_VERSION)))


func test_wrong_content_hash_is_refused_without_spawning() -> void:
	client_handshake.content_hash = "different-content"
	_join(client_root)
	await _assert_refused(Net.RefusalReason.CONTENT_MISMATCH)
	assert_true(client_handshake.refusal_message.to_lower().contains("content"))


func test_different_game_version_is_refused_without_spawning() -> void:
	client_handshake.game_version = "different-version"
	_join(client_root)
	await _assert_refused(Net.RefusalReason.WRONG_VERSION)
	assert_true(client_handshake.refusal_message.contains("different-version"))
	assert_true(client_handshake.refusal_message.contains(server_handshake.game_version))


func test_different_content_values_are_refused_even_with_matching_ids() -> void:
	client_handshake.fingerprint = "different-resource-values"
	_join(client_root)
	await _assert_refused(Net.RefusalReason.CONTENT_MISMATCH)
	assert_eq(client_handshake.content_hash, server_handshake.content_hash, "ids alone do not hide changed values")


func test_ninth_player_gets_server_full_without_receiving_players() -> void:
	for index: int in range(Net.MAX_PLAYERS - 1):
		var root: Node = client_root if index == 0 else _make_side("AcceptedClient%d" % index)
		_join(root)
		await wait_until(
			func() -> bool: return _player_count(server_root) == index + 2 and _player_count(root) == index + 2,
			5.0,
			"accepted player %d" % (index + 2)
		)
	assert_eq(_player_count(server_root), Net.MAX_PLAYERS)
	var ninth: Node = _make_side("NinthClient")
	var ninth_handshake: Handshake = ninth.get_node("Handshake") as Handshake
	watch_signals(ninth_handshake)
	_join(ninth)
	await wait_until(
		func() -> bool: return ninth_handshake.refusal_reason == Net.RefusalReason.SERVER_FULL,
		5.0,
		"ninth player refused"
	)
	assert_eq(ninth_handshake.refusal_reason, Net.RefusalReason.SERVER_FULL)
	assert_true(ninth_handshake.refusal_message.to_lower().contains("full"))
	assert_signal_emitted(ninth_handshake, "refused")
	assert_eq(_player_count(ninth), 0)
	assert_eq(_player_count(server_root), Net.MAX_PLAYERS)

## A real client may disconnect after spawning, before its deferred state request runs.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const PORT: int = 24645

var server_root: Node
var client_root: Node
var server_player: Player
var client_player: Player


func _make_side(side_name: String) -> Node:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	return root


func _add_player(root: Node, owner_id: int) -> Player:
	var player: Player = PLAYER.instantiate() as Player
	player.get_node("PoseSync").free()
	player.name = str(owner_id)
	player.set_multiplayer_authority(owner_id)
	root.add_child(player)
	player.set_physics_process(false)
	player.state_sync.set_physics_process(false)
	player.revive.set_physics_process(false)
	return player


func before_each() -> void:
	server_root = _make_side("SnapshotServer")
	client_root = _make_side("SnapshotClient")
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT, 1), OK)
	server_root.multiplayer.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client_root.multiplayer.multiplayer_peer = client_peer
	await wait_until(func() -> bool: return server_root.multiplayer.get_peers().size() == 1, 5.0, "client connected")
	var owner_id: int = client_root.multiplayer.get_unique_id()
	server_player = _add_player(server_root, owner_id)
	server_player.health.current = 45.0
	client_player = _add_player(client_root, owner_id)
	watch_signals(client_player.health)


func after_each() -> void:
	for root: Node in [client_root, server_root]:
		var path: NodePath = root.get_path()
		if root.multiplayer.multiplayer_peer:
			root.multiplayer.multiplayer_peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		root.free()
		get_tree().set_multiplayer(null, path)


func test_disconnect_before_deferred_snapshot_does_not_send_an_rpc() -> void:
	client_root.multiplayer.multiplayer_peer.close()
	await wait_process_frames(2)
	assert_engine_error_count(0, "the deferred request never queries or calls an inactive peer")
	assert_eq(client_player.health.current, 100.0)
	assert_signal_not_emitted(client_player.health, "health_changed", "no snapshot arrived after disconnect")


func test_removing_peer_before_deferred_snapshot_does_not_send_an_rpc() -> void:
	client_root.multiplayer.multiplayer_peer.close()
	client_root.multiplayer.multiplayer_peer = null
	await wait_process_frames(2)
	assert_engine_error_count(0, "the deferred request does not require an assigned peer")
	assert_eq(client_player.health.current, 100.0)
	assert_signal_not_emitted(client_player.health, "health_changed")

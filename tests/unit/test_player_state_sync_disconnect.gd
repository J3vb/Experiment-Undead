## A real client may disconnect after spawning, before its deferred state request runs.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var server_root: Node
var client_root: Node
var server_player: Player
var client_player: Player
var _port: int


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
	_port = TwoPeers.next_port()
	server_root = TwoPeers.make_side(self, "SnapshotServer")
	client_root = TwoPeers.make_side(self, "SnapshotClient")
	assert_eq(TwoPeers.host(server_root, _port, 1), OK)
	assert_eq(TwoPeers.join(client_root, _port), OK)
	await wait_until(func() -> bool: return server_root.multiplayer.get_peers().size() == 1, 5.0, "client connected")
	var owner_id: int = client_root.multiplayer.get_unique_id()
	server_player = _add_player(server_root, owner_id)
	server_player.health.current = 45.0
	client_player = _add_player(client_root, owner_id)
	watch_signals(client_player.health)


func after_each() -> void:
	for root: Node in [client_root, server_root]:
		TwoPeers.close_side(root)


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

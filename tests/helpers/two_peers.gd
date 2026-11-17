## Test helper for real ENet peers in one process. Each side is a node subtree with
## its own SceneMultiplayer; the helper hosts, joins, tears down and hands out ports.
class_name TwoPeers
extends RefCounted

const ADDRESS: String = "127.0.0.1"
const FIRST_PORT: int = 24800
const PORT_COUNT: int = 200

static var _next: int = 0
static var _admit: Callable


## A fresh localhost port, different from the last PORT_COUNT - 1 calls in this run.
static func next_port() -> int:
	var port: int = FIRST_PORT + _next
	_next = (_next + 1) % PORT_COUNT
	return port


## Adds a node named side_name under parent and gives it its own SceneMultiplayer.
static func make_side(parent: Node, side_name: String) -> Node:
	var root: Node = Node.new()
	root.name = side_name
	parent.add_child(root)
	parent.get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	return root


## Adds the "World" node and a "PlayerSpawner" for player_scene under root.
static func add_player_spawner(root: Node, player_scene: PackedScene) -> PlayerSpawner:
	var world: Node3D = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var spawner: PlayerSpawner = PlayerSpawner.new()
	spawner.name = "PlayerSpawner"
	spawner.player_scene = player_scene
	root.add_child(spawner)
	return spawner


static func host(side: Node, port: int, max_clients: int) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, max_clients)
	side.multiplayer.multiplayer_peer = peer
	return error


static func join(side: Node, port: int) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(ADDRESS, port)
	side.multiplayer.multiplayer_peer = peer
	return error


## Closes the side's peer, frees the side and removes its SceneMultiplayer.
## Close clients before the server.
static func close_side(root: Node) -> void:
	var tree: SceneTree = root.get_tree()
	var path: NodePath = root.get_path()
	if root.multiplayer.multiplayer_peer:
		root.multiplayer.multiplayer_peer.close()
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	root.free()
	tree.set_multiplayer(null, path)


## The players under root's "World" node.
static func players(root: Node) -> Array[Player]:
	var out: Array[Player] = []
	for child: Node in root.get_node("World").get_children():
		if child is Player:
			out.append(child as Player)
	return out


## Connects a friend side to the server already on the root multiplayer (Net.host), so the root
## plays by the co-op rules. Both sides admit without a Handshake. Undo with remove_friend().
static func add_friend(parent: Node, port: int) -> Node:
	var api: SceneMultiplayer = parent.get_tree().get_multiplayer() as SceneMultiplayer
	_admit = func(peer_id: int) -> void: api.complete_auth(peer_id)
	api.auth_callback = func(_peer_id: int, _data: PackedByteArray) -> void: pass
	api.peer_authenticating.connect(_admit)
	var friend: Node = make_side(parent, "Friend")
	var friend_api: SceneMultiplayer = friend.multiplayer as SceneMultiplayer
	friend_api.auth_callback = func(_peer_id: int, _data: PackedByteArray) -> void: pass
	friend_api.peer_authenticating.connect(func(peer_id: int) -> void: friend_api.complete_auth(peer_id))
	join(friend, port)
	var until: int = Time.get_ticks_msec() + 5000
	while api.get_peers().is_empty() and Time.get_ticks_msec() < until:
		await parent.get_tree().process_frame
	return friend


static func remove_friend(friend: Node) -> void:
	var api: SceneMultiplayer = friend.get_tree().get_multiplayer() as SceneMultiplayer
	close_side(friend)
	if api.peer_authenticating.is_connected(_admit):
		api.peer_authenticating.disconnect(_admit)
	# A static Callable that outlives the tree's multiplayer crashes the engine at exit.
	_admit = Callable()
	api.auth_callback = Callable()

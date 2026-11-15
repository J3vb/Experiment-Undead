## Makes one Player per connected peer, controlled by that peer, and
## replicates them to every client. Solo is peer 1 with no network.
class_name PlayerSpawner
extends MultiplayerSpawner

## Emitted on every peer once a player node is in the tree.
signal player_added(player: Player)

## Sideways gap between players spawning at the same marker.
const SPAWN_SPACING: float = 1.2

@export var player_scene: PackedScene
## False on a dedicated server: the server machine has no player of its own.
var spawn_local: bool = true

var _parent: Node3D
var _spawn_point: Transform3D


## Players are added under parent (the level), lined up from spawn_point.
func setup(parent: Node3D, spawn_point: Transform3D) -> void:
	_parent = parent
	_spawn_point = spawn_point
	spawn_function = _create
	spawn_path = get_path_to(parent)
	spawned.connect(func(node: Node) -> void: player_added.emit(node as Player))
	if not multiplayer.is_server():
		return
	multiplayer.peer_connected.connect(add_peer)
	multiplayer.peer_disconnected.connect(remove_peer)
	if spawn_local:
		add_peer(multiplayer.get_unique_id())
	for peer_id: int in multiplayer.get_peers():
		add_peer(peer_id)


func add_peer(peer_id: int) -> Player:
	if find_player(peer_id) != null:
		return null
	var index: int = 0
	for child: Node in _parent.get_children():
		if child is Player:
			index += 1
	var origin: Vector3 = _spawn_point.origin + _spawn_point.basis.x * SPAWN_SPACING * index
	var player: Player = spawn([peer_id, origin, _spawn_point.basis.get_euler().y]) as Player
	Log.info(&"net", &"player_joined", {"peer": peer_id})
	player_added.emit(player)
	return player


func remove_peer(peer_id: int) -> void:
	var player: Player = find_player(peer_id)
	if player:
		Log.info(&"net", &"player_left", {"peer": peer_id})
		player.queue_free()


func find_player(peer_id: int) -> Player:
	if _parent == null:
		return null
	return _parent.get_node_or_null(str(peer_id)) as Player


## Runs on the server and on every client with the same data.
func _create(data: Array) -> Node:
	var player: Player = player_scene.instantiate() as Player
	var peer_id: int = data[0]
	player.name = str(peer_id)
	player.net_id = peer_id
	player.set_multiplayer_authority(peer_id)
	player.position = data[1]
	player.rotation.y = data[2]
	return player

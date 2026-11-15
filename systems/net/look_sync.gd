## Relays each trusted client's worn gear once on join and only when its look changes.
class_name LookSync
extends Node

var _players: PlayerSpawner
var _codec: LookCodec = LookCodec.new()
var _looks: Dictionary[int, PackedByteArray] = {}
var _last_sent: PackedByteArray = PackedByteArray()


func setup(players: PlayerSpawner) -> void:
	_players = players
	players.player_added.connect(watch_player)
	multiplayer.peer_disconnected.connect(_forget_peer)


## Player replication only happens after the compatibility hello has been accepted.
func watch_player(player: Player) -> void:
	if player.is_multiplayer_authority():
		player.gear_rig.look_changed.connect(_publish)
	else:
		_apply_cached(player)
	if multiplayer.is_server() and player.net_id != 1:
		for peer_id: int in _looks:
			_receive_look.rpc_id(player.net_id, peer_id, _looks[peer_id])


func _publish(look: CharacterLook) -> void:
	var bytes: PackedByteArray = _codec.encode(look)
	if bytes == _last_sent:
		return
	_last_sent = bytes
	if multiplayer.is_server():
		_accept_look(multiplayer.get_unique_id(), bytes)
	else:
		_submit_look.rpc_id(1, bytes)


@rpc("any_peer", "call_remote", "reliable")
func _submit_look(bytes: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not multiplayer.get_peers().has(peer_id) or _players.find_player(peer_id) == null:
		return
	_accept_look(peer_id, bytes)


func _accept_look(peer_id: int, bytes: PackedByteArray) -> void:
	var safe_bytes: PackedByteArray = _codec.encode(_codec.decode(bytes))
	if _looks.get(peer_id) == safe_bytes:
		return
	_looks[peer_id] = safe_bytes
	var player: Player = _players.find_player(peer_id)
	if player != null:
		_apply_cached(player)
	if not multiplayer.get_peers().is_empty():
		_receive_look.rpc(peer_id, safe_bytes)


@rpc("authority", "call_remote", "reliable")
func _receive_look(peer_id: int, bytes: PackedByteArray) -> void:
	_looks[peer_id] = _codec.encode(_codec.decode(bytes))
	var player: Player = _players.find_player(peer_id)
	if player != null:
		_apply_cached(player)


func _apply_cached(player: Player) -> void:
	if not player.is_multiplayer_authority() and _looks.has(player.net_id):
		player.gear_rig.apply(_codec.decode(_looks[player.net_id]))


func _forget_peer(peer_id: int) -> void:
	_looks.erase(peer_id)

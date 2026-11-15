## Holds a nearby teammate's revive on the server; owners send only start/cancel intent.
class_name Revive
extends Node

const RANGE: float = 1.5
const HOLD_TIME: float = 3.0
const REWARD: int = 50

var progress: float = 0.0
var _player: Player
var _requested: Player
var _active: Player
var _elapsed: float = 0.0
var _local_elapsed: float = 0.0


func _init() -> void:
	name = "Revive"
	set_multiplayer_authority(1)


func _ready() -> void:
	_player = get_parent() as Player


## The HUD supplies held interact intent through the existing InputFrame seam.
func apply_frame(frame: InputFrame, delta: float) -> void:
	set_held(frame.has(InputFrame.INTERACT))
	if is_instance_valid(_requested) and can_revive(_requested):
		_local_elapsed += delta
		progress = minf(_local_elapsed / HOLD_TIME, 1.0)
	else:
		progress = 0.0


func set_held(held: bool) -> void:
	if not _player.is_multiplayer_authority():
		return
	var candidate: Player = nearest_target() if held else null
	if candidate == _requested:
		return
	_requested = candidate
	_local_elapsed = 0.0
	progress = 0.0
	if multiplayer.is_server():
		_begin(candidate)
	else:
		_request.rpc_id(1, candidate.net_id if candidate else 0)


func nearest_target() -> Player:
	var nearest: Player
	var distance: float = RANGE * RANGE
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var candidate: Player = node as Player
		if not can_revive(candidate):
			continue
		var squared: float = _player.global_position.distance_squared_to(candidate.global_position)
		if squared <= distance:
			distance = squared
			nearest = candidate
	return nearest


func can_revive(target: Player) -> bool:
	if not _online() or not is_instance_valid(target) or target == _player:
		return false
	if target.get_multiplayer() != multiplayer or target.is_queued_for_deletion():
		return false
	if _player.session and _player.session.is_over:
		return false
	if not _player.is_alive() or _player.is_downed or _player.is_dead:
		return false
	return (
		target.is_downed
		and not target.is_dead
		and _player.global_position.distance_squared_to(target.global_position) <= RANGE * RANGE
	)


func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	if not multiplayer.is_server() or not is_instance_valid(_active):
		return
	if not can_revive(_active) or not _connected(_player) or not _connected(_active):
		var target_id: int = _active.net_id
		_begin(null)
		_notify_rejected(target_id)
		return
	_elapsed += delta
	if _elapsed < HOLD_TIME:
		return
	var revived: Player = _active
	_begin(null)
	revived.state_sync.revive_player()
	_player.wallet.add(REWARD)


@rpc("any_peer", "call_remote", "reliable")
func _request(target_id: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != _player.get_multiplayer_authority():
		return
	var target: Player
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var candidate: Player = node as Player
		if candidate.net_id == target_id and candidate.get_multiplayer() == multiplayer:
			target = candidate
			break
	_begin(target)
	if target_id != 0 and _active == null:
		_notify_rejected(target_id)


func _notify_rejected(target_id: int) -> void:
	if _player.is_multiplayer_authority():
		_rejected(target_id)
	elif _connected(_player):
		_rejected.rpc_id(_player.get_multiplayer_authority(), target_id)


@rpc("authority", "call_remote", "reliable")
func _rejected(target_id: int) -> void:
	if is_instance_valid(_requested) and _requested.net_id == target_id:
		_requested = null
		_local_elapsed = 0.0
		progress = 0.0


func _begin(target: Player) -> void:
	_active = target if can_revive(target) else null
	_elapsed = 0.0


func _connected(player: Player) -> bool:
	var peer: int = player.get_multiplayer_authority()
	return not player.is_queued_for_deletion() and (peer == 1 or multiplayer.get_peers().has(peer))


func _online() -> bool:
	return multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer

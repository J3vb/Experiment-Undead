## Server side of a place change. The old session stays until every client sent away has
## disconnected (or was dropped), because packets they sent before the order still name its
## nodes. Hellos that arrive meanwhile wait for the next session's Handshake.
class_name PlaceChange
extends Node

## Every client left: the session may swap now. host_goes says the listen host follows.
signal finished(place: StringName, host_goes: bool)

var pending: StringName = &""
var _host_goes: bool = false
var _leaving: Array[int] = []
var _held_hellos: Array[Array] = []
var _deadline: Timer


func _ready() -> void:
	_deadline = Timer.new()
	_deadline.one_shot = true
	_deadline.process_mode = Node.PROCESS_MODE_ALWAYS
	_deadline.timeout.connect(_drop_leaving)
	add_child(_deadline)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	multiplayer.peer_connected.connect(_on_peer_joined)


## Call before sending the order. With nobody to wait for, finishes at once.
func start(next: StringName, peers: PackedInt32Array, host_goes: bool) -> void:
	pending = next
	_host_goes = host_goes
	_leaving.assign(peers)
	if _leaving.is_empty():
		_finish()
		return
	(multiplayer as SceneMultiplayer).auth_callback = _hold_hello
	_deadline.start(Net.CONNECT_TIMEOUT)


func is_leaving(peer_id: int) -> bool:
	return _leaving.has(peer_id)


## The next session's Handshake replays these once it is installed.
func take_held_hellos() -> Array[Array]:
	var held: Array[Array] = _held_hellos.duplicate()
	_held_hellos.clear()
	return held


func reset() -> void:
	_deadline.stop()
	_leaving.clear()
	_held_hellos.clear()
	pending = &""
	var api: SceneMultiplayer = multiplayer as SceneMultiplayer
	if api and api.auth_callback == _hold_hello:
		api.auth_callback = Handshake._ignore_auth


func _hold_hello(peer_id: int, packet: PackedByteArray) -> void:
	_held_hellos.append([peer_id, packet])


## A hello accepted just before the change connects now: send that peer away too.
func _on_peer_joined(peer_id: int) -> void:
	if pending.is_empty():
		return
	_leaving.append(peer_id)
	if multiplayer.get_peers().has(peer_id):
		Net.send_to_place(peer_id, pending)


func _on_peer_left(peer_id: int) -> void:
	_held_hellos = _held_hellos.filter(func(held: Array) -> bool: return held[0] != peer_id)
	if _leaving.has(peer_id):
		_leaving.erase(peer_id)
		if _leaving.is_empty() and not pending.is_empty():
			_finish()


## A client that never got the order is dropped, so its packets stop with the old session.
func _drop_leaving() -> void:
	for peer_id: int in _leaving.duplicate():
		Log.warn(&"net", &"place_change_kicked", {"peer": peer_id})
		if multiplayer.get_peers().has(peer_id):
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	_leaving.clear()
	if not pending.is_empty():
		_finish()


func _finish() -> void:
	_deadline.stop()
	var next: StringName = pending
	pending = &""
	finished.emit(next, _host_goes)

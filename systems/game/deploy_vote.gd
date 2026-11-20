## Ready-up vote in the hub. The first press on a deploy board proposes that place and
## readies the player; pressing again un-readies. When every connected player is ready,
## a countdown runs and the server deploys. Server decides; every peer gets
## Events.deploy_vote_changed, and a late joiner gets the running vote once.
class_name DeployVote
extends Node

const COUNTDOWN: float = 5.0
## Where a co-op match returns to.
const HUB: StringName = &"hub"

var session: GameSession
## The voted place (a screens id). Empty while no vote runs.
var place: StringName = &""

var _ready_ids: Array[int] = []
## Seconds left before the deploy; negative while not everyone is ready.
var _countdown: float = -1.0


func _ready() -> void:
	name = "DeployVote"
	multiplayer.peer_connected.connect(_on_peers_changed.unbind(1), CONNECT_DEFERRED)
	multiplayer.peer_disconnected.connect(_on_peers_changed.unbind(1), CONNECT_DEFERRED)
	multiplayer.connected_to_server.connect(func() -> void: _request_snapshot.rpc_id(1))


func is_ready(peer_id: int) -> bool:
	return _ready_ids.has(peer_id)


func countdown_left() -> float:
	return maxf(_countdown, 0.0)


## Server only, from the deploy board's interact().
func toggle_ready(player: Player, next_place: StringName) -> void:
	if not multiplayer.is_server() or not session.is_hub or Net.changing_place:
		return
	if place.is_empty():
		if not Content.has(UI.TYPE, next_place):
			Log.warn(&"net", &"deploy_refused", {"place": String(next_place), "reason": "unknown_place"})
			return
		place = next_place
	elif next_place != place:
		return
	if _ready_ids.has(player.net_id):
		_ready_ids.erase(player.net_id)
	else:
		_ready_ids.append(player.net_id)
	_recheck()


func _physics_process(delta: float) -> void:
	if _countdown < 0.0:
		return
	_countdown -= delta
	if _countdown > 0.0 or not multiplayer.is_server():
		return
	deploy(place)


## Server only: sends every peer from the hub to target (a screens id). False when refused.
func deploy(target: StringName) -> bool:
	if not session.is_hub or not multiplayer.is_server() or not Content.has(UI.TYPE, target):
		Log.warn(&"net", &"deploy_refused", {"place": String(target), "hub": session.is_hub})
		return false
	_clear()
	Net.change_place(target, session.has_local_player)
	return true


func _on_peers_changed() -> void:
	if is_inside_tree() and multiplayer.is_server() and not place.is_empty():
		_recheck()


## Drops peers who left, then starts or stops the countdown. A joiner starts not ready.
func _recheck() -> void:
	var connected: Array[int] = []
	for peer_id: int in multiplayer.get_peers():
		if not Net.place_change.is_leaving(peer_id):
			connected.append(peer_id)
	if session.has_local_player:
		connected.append(multiplayer.get_unique_id())
	for peer_id: int in _ready_ids.duplicate():
		if not connected.has(peer_id):
			_ready_ids.erase(peer_id)
	if _ready_ids.is_empty():
		_clear()
		return
	var everyone: bool = connected.all(func(peer_id: int) -> bool: return _ready_ids.has(peer_id))
	if not everyone:
		_countdown = -1.0
	elif _countdown < 0.0:
		_countdown = COUNTDOWN
	_send_state()


func _clear() -> void:
	place = &""
	_ready_ids.clear()
	_countdown = -1.0
	_send_state()


func _send_state() -> void:
	if multiplayer.get_peers().is_empty():
		_receive_state(place, _ready_ids.duplicate(), _countdown)
	else:
		_receive_state.rpc(place, _ready_ids, _countdown)


@rpc("any_peer", "call_remote", "reliable")
func _request_snapshot() -> void:
	if multiplayer.is_server() and not place.is_empty():
		_receive_state.rpc_id(multiplayer.get_remote_sender_id(), place, _ready_ids, _countdown)


@rpc("authority", "call_local", "reliable")
func _receive_state(next_place: StringName, ready_ids: Array, countdown: float) -> void:
	place = next_place
	_ready_ids.assign(ready_ids)
	_countdown = countdown
	Events.deploy_vote_changed.emit(place, _ready_ids.duplicate(), countdown_left())


## After a co-op match ("Back to hub" on the results). A listen host takes the squad
## along; a client goes back to the server, which has moved (or soon moves) to the hub.
func back_to_hub() -> void:
	if Net.is_coop(multiplayer) and multiplayer.is_server():
		Net.change_place(HUB, true)
	else:
		Net.go_to(HUB)

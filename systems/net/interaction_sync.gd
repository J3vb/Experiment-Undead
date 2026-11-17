## Co-op interact requests and world state. A client asks to use an
## interactable; the server checks the request and runs the same interact()
## as solo. Interactable and Level state changes go to every client, and a
## late joiner gets them all once in a snapshot.
class_name InteractionSync
extends Node

## Pose lag plus large interactable areas, on top of the player's reach.
const REACH_SLACK: float = 2.0
const REQUEST_GAP: float = 0.1
const LEVEL_PATH: NodePath = ^"."

var session: GameSession

var _time: float = 0.0
var _next_warning: float = 0.0
var _last_request: Dictionary[int, float] = {}


func _ready() -> void:
	name = "InteractionSync"
	multiplayer.peer_disconnected.connect(func(peer_id: int) -> void: _last_request.erase(peer_id))
	multiplayer.connected_to_server.connect(func() -> void: _request_snapshot.rpc_id(1))
	var level: Level = session.level
	level.area_opened.connect(func(_area: StringName) -> void: _send_level())
	level.power_turned_on.connect(_send_level)
	for node: Node in level.find_children("*", "Area3D", true, false):
		var target: Interactable = node as Interactable
		if target:
			target.state_changed.connect(_send_state.bind(target))
			target.retired.connect(_on_retired.bind(target))


func _physics_process(delta: float) -> void:
	_time += delta


## Client side: ask the server to use focus for player.
func request(player: Player, focus: Interactable) -> void:
	request_interact.rpc_id(1, session.level.get_path_to(focus), focus.owner_facts(player))


@rpc("any_peer", "call_remote", "reliable")
func request_interact(path: NodePath, facts: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Player = session.players.find_player(sender)
	var target: Interactable = _find(path)
	var reason: StringName = _check(sender, player, target)
	if reason != &"":
		_reject(sender, path, reason)
		return
	_last_request[sender] = _time
	target.interact(player, facts)


func _check(sender: int, player: Player, target: Interactable) -> StringName:
	if player == null or player.is_dead or not player.is_alive() or player.is_downed:
		return &"player_not_alive"
	if session.is_over:
		return &"match_over"
	if target == null or target.is_queued_for_deletion():
		return &"unknown_path"
	if player.global_position.distance_to(target.global_position) > player.interact_range + REACH_SLACK:
		return &"out_of_range"
	if not target.accepts_requests():
		return &"not_networked_yet"
	return &"rate_limited" if _time - _last_request.get(sender, -INF) < REQUEST_GAP else &""


func _find(path: NodePath) -> Interactable:
	if path.is_empty() or path.is_absolute():
		return null
	var node: Node = session.level.get_node_or_null(path)
	if node == null or not session.level.is_ancestor_of(node):
		return null
	return node as Interactable


func _reject(sender: int, path: NodePath, reason: StringName) -> void:
	_receive_result.rpc_id(sender, path, false)
	if _time < _next_warning:
		return
	_next_warning = _time + 1.0
	var event: StringName = &"interaction_rate_limited" if reason == &"rate_limited" else &"interaction_rejected"
	Log.warn(&"net", event, {"peer": sender, "reason": reason, "path": str(path)})


## Server side: the buy or denied sound for a remote buyer.
func send_result(player: Player, target: Interactable, paid: bool) -> void:
	if multiplayer.get_peers().has(player.net_id):
		_receive_result.rpc_id(player.net_id, session.level.get_path_to(target), paid)


@rpc("authority", "call_remote", "reliable")
func _receive_result(path: NodePath, paid: bool) -> void:
	var target: Interactable = _find(path)
	if target:
		target.play_result(paid)


func _send_state(target: Interactable) -> void:
	if multiplayer.is_server() and not multiplayer.get_peers().is_empty():
		_receive_state.rpc(session.level.get_path_to(target), target.net_state())


func _send_level() -> void:
	if multiplayer.is_server() and not multiplayer.get_peers().is_empty():
		_receive_state.rpc(LEVEL_PATH, session.level.net_state())


func _on_retired(target: Interactable) -> void:
	if not multiplayer.is_server():
		return
	session.level.removed.append(session.level.get_path_to(target))
	_send_level()


@rpc("authority", "call_remote", "reliable")
func _receive_state(path: NodePath, state: Dictionary) -> void:
	if path == LEVEL_PATH:
		session.level.apply_net_state(state)
		return
	var target: Interactable = _find(path)
	if target:
		target.apply_net_state(state)


@rpc("any_peer", "call_remote", "reliable")
func _request_snapshot() -> void:
	if not multiplayer.is_server():
		return
	var states: Dictionary = {str(LEVEL_PATH): session.level.net_state()}
	for node: Node in session.level.find_children("*", "Area3D", true, false):
		var target: Interactable = node as Interactable
		if target and not target.is_queued_for_deletion() and not target.net_state().is_empty():
			states[str(session.level.get_path_to(target))] = target.net_state()
	_receive_snapshot.rpc_id(multiplayer.get_remote_sender_id(), states)


@rpc("authority", "call_remote", "reliable")
func _receive_snapshot(states: Dictionary) -> void:
	for key: String in states:
		_receive_state(NodePath(key), states[key])

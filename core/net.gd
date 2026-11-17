## Network role, admission failures and connection deadline. Solo has no open port.
## Shared gameplay changes check Net.is_authority(); solo or co-op rules check is_coop(). See docs/MULTIPLAYER.md.
extends Node

signal connection_error(reason: StringName, details: Dictionary)
signal join_started(address: String)
signal join_succeeded
## Server only: the session must change to this place (the dedicated server swaps its session).
signal place_changed(place: StringName)
## The first friend joined (true) or the last one left (false). A world alone plays solo.
signal coop_changed(on: bool)

## Sent on the wire as ints: append only, never reorder.
enum RefusalReason { WRONG_VERSION, CONTENT_MISMATCH, SERVER_FULL }

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 8
const CONNECT_TIMEOUT: float = 6.0

## The menu sets this before loading the match, so replicated scenes already exist.
var pending_join: String = ""
var last_error: Dictionary = {}
var joining: bool = false
## Kept through disconnect so the menu can explain rejected hellos.
var refusal_reason: int = -1
var refusal_message: String = ""
var player_limit: int = MAX_PLAYERS
## The screens id of the place this peer runs (hub, match). Empty when started outside the menu.
var place: StringName = &""
## True from a place change order until the next host() or join(): the old session's
## disconnect is planned, so nobody shows the lost-connection error.
var changing_place: bool = false
## True while the results screen is up: a place change order then waits for the player.
var holds_place: bool = false
## Enter world opens it; the pause screen reads world.state.
var world: OwnWorld = OwnWorld.new()
## Answers server browser queries while this PC runs a world or a dedicated server.
var info: ServerInfo

var _next_net_id: int = 1
var _target: String = ""
## Server: peers sent to another place that have not disconnected yet. They get no player.
var _leaving: Array[int] = []
## multiplayer.is_server() is also true for a client still in its hello, so hosting is tracked here.
var _hosting: bool = false
var _leave_deadline: Timer
var _deadline: Timer
var _signals_bound: bool = false
var _connected: bool = false
var _coop: bool = false


func _ready() -> void:
	info = ServerInfo.new()
	add_child(info)


func is_authority() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func is_online() -> bool:
	return _live(multiplayer.multiplayer_peer)


## Co-op rules apply: a client, or a server with a friend connected. Read it when a rule is used
## (friends come and go). Pass the caller's multiplayer when it differs (tests use subtrees).
func is_coop(api: MultiplayerAPI = null) -> bool:
	var on: MultiplayerAPI = api if api else multiplayer
	return _live(on.multiplayer_peer) and (not on.is_server() or not on.get_peers().is_empty())


static func _live(peer: MultiplayerPeer) -> bool:
	return (
		peer != null
		and not peer is OfflineMultiplayerPeer
		and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED
	)


func host(port: int, max_players: int = MAX_PLAYERS) -> Error:
	_configure()
	changing_place = false
	last_error.clear()
	player_limit = clampi(max_players, 1, MAX_PLAYERS)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# Pending hellos need transport slots to receive SERVER_FULL before disconnect.
	var err: Error = peer.create_server(port, MAX_PLAYERS * 2)
	if err != OK:
		_record_error(&"port_in_use", {"port": port})
		return err
	multiplayer.multiplayer_peer = peer
	_hosting = true
	Log.info(&"net", &"hosting", {"port": port, "max_players": player_limit})
	return OK


func join(address: String) -> Error:
	_configure()
	changing_place = false
	last_error.clear()
	refusal_reason = -1
	refusal_message = ""
	var target: Array = ServerAddress.parse(address)
	_target = "%s:%d" % target
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(target[0], target[1])
	if err != OK:
		_record_error(&"timeout", {"address": _target})
		return err
	joining = true
	multiplayer.multiplayer_peer = peer
	_deadline.start(CONNECT_TIMEOUT)
	join_started.emit(_target)
	Log.info(&"net", &"joining", {"address": target[0], "port": target[1]})
	return OK


## Joins pending_join if the menu set one. OK when there is nothing to join.
## A listen host that changed place kept its port open and just carries on.
func start_pending_join() -> Error:
	if changing_place and _hosting:
		changing_place = false
		return OK
	if pending_join.is_empty():
		return OK
	var address: String = pending_join
	pending_join = ""
	return join(address)


func leave() -> void:
	if changing_place and _hosting and is_online():
		return
	_hosting = false
	joining = false
	_connected = false
	_leaving.clear()
	if not changing_place:
		pending_join = ""
		player_limit = MAX_PLAYERS
	if _deadline:
		_deadline.stop()
	if is_online():
		if multiplayer.is_server() and not multiplayer.get_peers().is_empty():
			_notify_host_ended()
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_update_coop()


## Server: sends every client to next. They leave and rejoin into the new session
## themselves (closing their connection here would drop the order); until then they
## get no player. Clients that never leave are dropped after CONNECT_TIMEOUT.
func change_place(next: StringName) -> void:
	place = next
	Log.info(&"net", &"place_changed", {"place": String(next), "players": multiplayer.get_peers().size()})
	if is_online() and multiplayer.is_server() and not multiplayer.get_peers().is_empty():
		_leaving.assign(multiplayer.get_peers())
		_go_to_place.rpc(next)
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).host.flush()
		_leave_deadline.start(CONNECT_TIMEOUT)
	place_changed.emit(next)


func is_leaving(peer_id: int) -> bool:
	return _leaving.has(peer_id)


func _drop_leaving() -> void:
	if not is_online() or not multiplayer.is_server():
		return
	for peer_id: int in _leaving.duplicate():
		if multiplayer.get_peers().has(peer_id):
			Log.warn(&"net", &"place_change_kicked", {"peer": peer_id})
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	_leaving.clear()


## Loads next on this peer. Online, the next session joins the same server again
## (a listen host keeps its port open) when it starts.
func go_to(next: StringName) -> void:
	place = next
	Log.info(&"net", &"go_to_place", {"place": String(next), "online": is_online()})
	if is_online():
		changing_place = true
		if not _hosting:
			pending_join = _target
	UI.replace(next)


## Forgets a held place change (the player went to the main menu instead).
func cancel_place_change() -> void:
	changing_place = false
	pending_join = ""


@rpc("authority", "reliable")
func _go_to_place(next: StringName) -> void:
	if not holds_place:
		go_to(next)
		return
	# The results stay up; the connection closes quietly and "Back to hub" rejoins.
	Log.info(&"net", &"place_change_held", {"place": String(next)})
	place = next
	changing_place = true
	pending_join = _target
	leave()


func _exit_tree() -> void:
	world.quit()
	if _signals_bound:
		leave()


## Clients close their transport after consuming the notice. Drain those
## disconnects, with a deadline for unreachable clients, before closing the socket.
func _notify_host_ended() -> void:
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var waiting: Array[ENetPacketPeer] = []
	for peer_id: int in multiplayer.get_peers():
		waiting.append(peer.get_peer(peer_id))
	_host_ended_match.rpc()
	peer.host.flush()
	var until: int = Time.get_ticks_msec() + int(CONNECT_TIMEOUT * 1000.0)
	while not waiting.is_empty() and Time.get_ticks_msec() < until:
		var event: Array = peer.host.service(maxi(0, mini(100, until - Time.get_ticks_msec())))
		if event[0] == ENetConnection.EVENT_DISCONNECT:
			waiting.erase(event[1])
		elif event[0] == ENetConnection.EVENT_ERROR:
			break


func _configure() -> void:
	var api: SceneMultiplayer = multiplayer as SceneMultiplayer
	if not api.auth_callback.is_valid():
		# The match installs Handshake before processing hellos; transport alone never admits a peer.
		api.auth_callback = func(_peer_id: int, _packet: PackedByteArray) -> void: pass
	api.auth_timeout = CONNECT_TIMEOUT
	if _signals_bound:
		return
	_signals_bound = true
	_deadline = Timer.new()
	_deadline.one_shot = true
	_deadline.process_mode = Node.PROCESS_MODE_ALWAYS
	_deadline.timeout.connect(func() -> void: _fail_join(&"timeout", {"address": _target}))
	add_child(_deadline)
	_leave_deadline = Timer.new()
	_leave_deadline.one_shot = true
	_leave_deadline.process_mode = Node.PROCESS_MODE_ALWAYS
	_leave_deadline.timeout.connect(_drop_leaving)
	add_child(_leave_deadline)
	api.peer_disconnected.connect(func(peer_id: int) -> void: _leaving.erase(peer_id))
	api.peer_connected.connect(func(_peer_id: int) -> void: _update_coop())
	api.peer_disconnected.connect(func(_peer_id: int) -> void: _update_coop.call_deferred())
	api.peer_authentication_failed.connect(_on_authentication_failed, CONNECT_DEFERRED)
	api.connected_to_server.connect(_on_connected)
	api.connection_failed.connect(_on_connection_failed)
	api.server_disconnected.connect(_on_server_disconnected)


## Handshake owns admission. Keep its reason while the refusal ACK reaches the server.
## reason_name is &"refused" for a code from a newer server that this build does not know.
func report_refusal(reason: int, reason_name: StringName, details: Dictionary) -> void:
	if not joining:
		return
	refusal_reason = reason
	_deadline.stop()
	_record_error(reason_name, details)


func _on_authentication_failed(_peer_id: int) -> void:
	if not joining:
		return
	if refusal_reason >= 0:
		leave()
		multiplayer.connection_failed.emit()
	else:
		_fail_join(&"timeout", {"address": _target})


func _update_coop() -> void:
	if is_coop() != _coop:
		_coop = not _coop
		Log.info(&"net", &"coop_started" if _coop else &"coop_ended", {"peers": multiplayer.get_peers().size()})
		coop_changed.emit(_coop)


func _on_connected() -> void:
	if not joining:
		return
	joining = false
	_connected = true
	_deadline.stop()
	join_succeeded.emit()


func _on_connection_failed() -> void:
	if joining:
		joining = false
		_deadline.stop()
		_record_error(&"timeout", {"address": _target})


func _on_server_disconnected() -> void:
	if changing_place:
		return
	if joining and refusal_reason >= 0:
		leave()
		return
	if not joining and not _connected:
		return
	var reason: StringName = &"timeout" if joining else &"lost_connection"
	joining = false
	_deadline.stop()
	_record_error(reason, {"address": _target})
	leave()


func _fail_join(reason: StringName, details: Dictionary) -> void:
	if not joining:
		return
	_record_error(reason, details)
	leave()
	multiplayer.connection_failed.emit()


func _record_error(reason: StringName, details: Dictionary) -> void:
	last_error = {"reason": reason, "details": details}
	connection_error.emit(reason, details)


@rpc("authority", "reliable")
func _host_ended_match() -> void:
	_record_error(&"host_ended", {})
	leave()
	multiplayer.server_disconnected.emit()


## Unique id for anything spawned during a session. Authority only.
func allocate_id() -> int:
	var id: int = _next_net_id
	_next_net_id += 1
	return id


func reset_ids() -> void:
	_next_net_id = 1

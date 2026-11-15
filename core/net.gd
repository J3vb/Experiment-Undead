## Network role, admission failures and connection deadline. Solo has no open port.
## Shared gameplay changes check Net.is_authority(). See docs/MULTIPLAYER.md.
extends Node

signal connection_error(reason: StringName, details: Dictionary)
signal join_started(address: String)
signal join_succeeded

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 8
const CONNECT_TIMEOUT: float = 6.0

## The menu sets this before loading the match, so replicated scenes already exist.
var pending_join: String = ""
var last_error: Dictionary = {}
var joining: bool = false

var _next_net_id: int = 1
var _target: String = ""
var _capacity: int = MAX_PLAYERS
var _fingerprint: String = ""
var _deadline: Timer
var _signals_bound: bool = false
var _connected: bool = false
var _reserved: Dictionary[int, bool] = {}


func is_authority() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func is_online() -> bool:
	return (
		multiplayer.multiplayer_peer != null
		and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED
	)


func host(port: int, max_players: int = MAX_PLAYERS) -> Error:
	_configure()
	last_error.clear()
	_capacity = clampi(max_players, 1, MAX_PLAYERS)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# One spare transport slot lets a full server explain its refusal before admission.
	var err: Error = peer.create_server(port, MAX_PLAYERS + 1)
	if err != OK:
		_record_error(&"port_in_use", {"port": port})
		return err
	_fingerprint = content_fingerprint()
	multiplayer.multiplayer_peer = peer
	Log.info(&"net", &"hosting", {"port": port, "max_players": _capacity})
	return OK


func join(address: String) -> Error:
	_configure()
	last_error.clear()
	var target: Array = parse_address(address)
	_target = "%s:%d" % target
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(target[0], target[1])
	if err != OK:
		_record_error(&"timeout", {"address": _target})
		return err
	_fingerprint = content_fingerprint()
	joining = true
	multiplayer.multiplayer_peer = peer
	_deadline.start(CONNECT_TIMEOUT)
	join_started.emit(_target)
	Log.info(&"net", &"joining", {"address": target[0], "port": target[1]})
	return OK


## Joins pending_join if the menu set one. OK when there is nothing to join.
func start_pending_join() -> Error:
	if pending_join.is_empty():
		return OK
	var address: String = pending_join
	pending_join = ""
	return join(address)


func leave() -> void:
	joining = false
	_connected = false
	pending_join = ""
	if _deadline:
		_deadline.stop()
	if is_online():
		if multiplayer.is_server() and not multiplayer.get_peers().is_empty():
			_notify_host_ended()
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reserved.clear()


func _exit_tree() -> void:
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
	if _signals_bound:
		return
	_signals_bound = true
	_deadline = Timer.new()
	_deadline.one_shot = true
	_deadline.process_mode = Node.PROCESS_MODE_ALWAYS
	_deadline.timeout.connect(func() -> void: _fail_join(&"timeout", {"address": _target}))
	add_child(_deadline)
	var api: SceneMultiplayer = multiplayer as SceneMultiplayer
	api.auth_callback = _authenticate
	api.auth_timeout = CONNECT_TIMEOUT
	api.peer_authenticating.connect(_on_authenticating)
	api.peer_authentication_failed.connect(_on_authentication_failed)
	api.peer_connected.connect(func(id: int) -> void: _reserved.erase(id))
	api.peer_disconnected.connect(func(id: int) -> void: _reserved.erase(id))
	api.connected_to_server.connect(_on_connected)
	api.connection_failed.connect(_on_connection_failed)
	api.server_disconnected.connect(_on_server_disconnected)


func _on_authenticating(peer_id: int) -> void:
	if not multiplayer.is_server():
		(multiplayer as SceneMultiplayer).send_auth(peer_id, var_to_bytes(_hello()))


func _hello() -> Dictionary:
	return {"version": Build.version, "protocol": Build.PROTOCOL_VERSION, "content": _fingerprint}


func _authenticate(peer_id: int, packet: PackedByteArray) -> void:
	var decoded: Variant = bytes_to_var(packet)
	if not decoded is Dictionary:
		return
	var remote: Dictionary = decoded
	var api: SceneMultiplayer = multiplayer as SceneMultiplayer
	if multiplayer.is_server():
		var reply: Dictionary = _hello()
		var rejection: Dictionary = rejection_for(remote)
		if not rejection.is_empty():
			reply.merge(rejection)
		else:
			_reserved[peer_id] = true
		api.send_auth(peer_id, var_to_bytes(reply))
		if rejection.is_empty():
			api.complete_auth(peer_id)
	elif peer_id == 1:
		if remote.has("reason"):
			_fail_join.call_deferred(StringName(remote["reason"]), remote.get("details", {}))
		else:
			api.complete_auth(peer_id)


## Admission reasons remain data; the menu owns their wording.
func rejection_for(remote: Dictionary) -> Dictionary:
	var count: int = multiplayer.get_peers().size() + _reserved.size()
	for player: Node in get_tree().get_nodes_in_group(&"players"):
		if player.get_multiplayer_authority() == 1:
			count += 1
	if count >= _capacity:
		return {"reason": &"server_full", "details": {"players": count, "max_players": _capacity}}
	if remote.get("protocol") != Build.PROTOCOL_VERSION or remote.get("version") != Build.version:
		return {
			"reason": &"wrong_version",
			"details": {"server_version": Build.version, "client_version": str(remote.get("version", "unknown"))}
		}
	if remote.get("content") != _fingerprint:
		return {"reason": &"content_mismatch", "details": {}}
	return {}


func _on_authentication_failed(peer_id: int) -> void:
	_reserved.erase(peer_id)
	if joining:
		_fail_join(&"timeout", {"address": _target})


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


## Compare gameplay resource values, so editor and exported resource formats agree.
func content_fingerprint() -> String:
	var rows: Array[String] = []
	var categories: PackedStringArray = DirAccess.get_directories_at(Content.ROOT)
	categories.sort()
	for category: String in categories:
		var ids: PackedStringArray = PackedStringArray(Content.ids(StringName(category)))
		ids.sort()
		for id: String in ids:
			rows.append(
				"%s/%s:%s" % [category, id, _content_value(Content.get_item(StringName(category), StringName(id)))]
			)
	return "\n".join(rows).sha256_text()


func _content_value(value: Variant) -> String:
	if value is Resource:
		var resource: Resource = value
		if resource.get_script() == null:
			return resource.resource_path
		var fields: Array[String] = []
		for property: Dictionary in resource.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE:
				fields.append("%s=%s" % [property.name, _content_value(resource.get(property.name))])
		return ";".join(fields)
	if value is Array:
		var entries: Array[String] = []
		for entry: Variant in value:
			entries.append(_content_value(entry))
		return "[%s]" % ",".join(entries)
	if value is Dictionary:
		var fields: Array[String] = []
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key: Variant in keys:
			fields.append("%s=%s" % [key, _content_value(value[key])])
		return "{%s}" % ",".join(fields)
	return var_to_str(value)


## "1.2.3.4:7777" -> ["1.2.3.4", 7777]. Missing or bad port uses DEFAULT_PORT.
static func parse_address(text: String) -> Array:
	var address: String = text.strip_edges()
	var port: int = DEFAULT_PORT
	var colon: int = address.rfind(":")
	if colon > 0 and address.substr(colon + 1).is_valid_int():
		port = address.substr(colon + 1).to_int()
		address = address.substr(0, colon)
	if address.is_empty():
		address = "127.0.0.1"
	return [address, port]


## Unique id for anything spawned during a session. Authority only.
func allocate_id() -> int:
	var id: int = _next_net_id
	_next_net_id += 1
	return id


func reset_ids() -> void:
	_next_net_id = 1

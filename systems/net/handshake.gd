## Checks the hello before SceneMultiplayer exposes a peer or replicates any players.
class_name Handshake
extends Node

signal accepted(peer_id: int)
## reason may be a code this build does not know (from a newer server).
signal refused(reason: int, client_protocol: int, server_protocol: int)

## Shown by clients that do not know the reason code. Keys of hello and replies listed
## in docs/MULTIPLAYER.md are frozen: later versions add keys, never rename or remove them.
const SERVER_TEXT: Dictionary = {
	Net.RefusalReason.WRONG_VERSION: "This server runs another version of the game.",
	Net.RefusalReason.CONTENT_MISMATCH: "Your game content differs from the server's.",
	Net.RefusalReason.SERVER_FULL: "The server is full.",
	Net.RefusalReason.SERVER_UPDATING: "The server is restarting for an update. Try again in a minute.",
}

var protocol_version: int = Build.PROTOCOL_VERSION
var content_hash: String = Build.content_hash
var game_version: String = Build.version
var fingerprint: String = ""
var max_players: int = Net.MAX_PLAYERS
var has_local_player: bool = true
## Set by a draining dedicated server in the hub: new hellos get SERVER_UPDATING.
var draining: bool = false
var refusal_reason: int = -1
var refusal_message: String = ""

var _scene: SceneMultiplayer
var _display_name: String = "Survivor"
var _level: int = 1
var _levels: Dictionary[int, int] = {}
var _names: Dictionary[int, String] = {}
var _accepted: Dictionary[int, bool] = {}
var _rejected: Dictionary[int, bool] = {}


## Install on both sides before opening a connection. No profile data is saved here.
func setup(display_name: String = "Survivor", level: int = 1) -> void:
	_display_name = CharacterProfile.clean_name(display_name)
	_level = level
	if fingerprint.is_empty():
		fingerprint = Build.content_fingerprint()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--test-protocol="):
			protocol_version = arg.trim_prefix("--test-protocol=").to_int()
	_scene = multiplayer as SceneMultiplayer
	_scene.auth_timeout = Net.CONNECT_TIMEOUT
	_scene.auth_callback = _receive_auth
	_scene.peer_authenticating.connect(_on_peer_authenticating)
	_scene.peer_disconnected.connect(_forget_peer)
	_scene.peer_authentication_failed.connect(_forget_peer)


func _exit_tree() -> void:
	if _scene == null:
		return
	if _scene.auth_callback == _receive_auth:
		# Never an empty callback: that would admit a peer with no hello while sessions swap.
		_scene.auth_callback = Handshake._ignore_auth
	if _scene.peer_authenticating.is_connected(_on_peer_authenticating):
		_scene.peer_authenticating.disconnect(_on_peer_authenticating)
	if _scene.peer_disconnected.is_connected(_forget_peer):
		_scene.peer_disconnected.disconnect(_forget_peer)
	if _scene.peer_authentication_failed.is_connected(_forget_peer):
		_scene.peer_authentication_failed.disconnect(_forget_peer)


static func _ignore_auth(_peer_id: int, _packet: PackedByteArray) -> void:
	pass


func _on_peer_authenticating(peer_id: int) -> void:
	if not multiplayer.is_server() and peer_id == 1:
		_send(peer_id, hello())


## The client's hello. Frozen keys (docs/MULTIPLAYER.md) never change; later versions only add keys.
func hello() -> Dictionary:
	return {
		"t": "hello",
		"protocol": protocol_version,
		"version": game_version,
		"content": content_hash,
		"fingerprint": fingerprint,
		"name": _display_name,
		"level": _level,
	}


func _receive_auth(peer_id: int, bytes: PackedByteArray) -> void:
	var json: JSON = JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return
	var message: Dictionary = json.data
	var kind: String = str(message.get("t", ""))
	if multiplayer.is_server():
		_receive_as_server(peer_id, kind, message)
	elif peer_id == 1:
		_receive_as_client(kind, message)


func _receive_as_server(peer_id: int, kind: String, message: Dictionary) -> void:
	if _rejected.has(peer_id):
		if kind == "refused_ack":
			_scene.disconnect_peer(peer_id)
	elif not _accepted.has(peer_id) and kind == "hello":
		_receive_hello(peer_id, message)


func _receive_as_client(kind: String, message: Dictionary) -> void:
	if kind == "accepted":
		_accept_place(StringName(str(message.get("place", ""))))
	elif kind == "refused":
		_receive_refusal(message)


## Protocol and version are read first, so any older or newer hello gets WRONG_VERSION.
func _receive_hello(peer_id: int, hello_data: Dictionary) -> void:
	var remote_protocol: int = _int_field(hello_data, "protocol", -1)
	var remote_version: String = str(hello_data.get("version", ""))
	var players: int = _accepted.size() + int(has_local_player)
	if remote_protocol != protocol_version or remote_version != game_version:
		_reject(peer_id, Net.RefusalReason.WRONG_VERSION)
	elif str(hello_data.get("content", "")) != content_hash or str(hello_data.get("fingerprint", "")) != fingerprint:
		_reject(peer_id, Net.RefusalReason.CONTENT_MISMATCH)
	elif draining:
		_reject(peer_id, Net.RefusalReason.SERVER_UPDATING)
	elif players >= max_players:
		_reject(peer_id, Net.RefusalReason.SERVER_FULL, {"players": players, "max_players": max_players})
	else:
		_admit(peer_id, hello_data)


func _admit(peer_id: int, hello_data: Dictionary) -> void:
	var level: Variant = hello_data.get("level")
	if not (level is float or level is int) or not is_finite(float(level)):
		Log.warn(&"net", &"hello_bad_level", {"peer": peer_id, "level": str(level)})
		level = 1
	_levels[peer_id] = clampi(int(level), 1, 50)
	_names[peer_id] = CharacterProfile.clean_name(str(hello_data.get("name", "")))
	_accepted[peer_id] = true
	_send(peer_id, {"t": "accepted", "place": String(Net.place)})
	_scene.complete_auth(peer_id)
	accepted.emit(peer_id)


func _reject(peer_id: int, reason: Net.RefusalReason, extra: Dictionary = {}) -> void:
	_rejected[peer_id] = true
	var reply: Dictionary = {
		"t": "refused",
		"reason": reason,
		"server_version": game_version,
		"server_protocol": protocol_version,
		"text": SERVER_TEXT.get(reason, "Cannot join this server."),
	}
	reply.merge(extra)
	_send(peer_id, reply)


func _receive_refusal(reply: Dictionary) -> void:
	var code: int = _int_field(reply, "reason", -1)
	refusal_reason = code if code >= 0 else Net.RefusalReason.size()
	var server_protocol: int = _int_field(reply, "server_protocol", -1)
	var details: Dictionary = _refusal_details(reply)
	refusal_message = _refusal_text(server_protocol, details)
	Net.refusal_reason = refusal_reason
	Net.refusal_message = refusal_message
	(
		Log
		. info(
			&"net",
			&"join_refused",
			{
				"reason": reason_key(refusal_reason),
				"older": details.get("older", ""),
				"message": refusal_message,
				"client_protocol": protocol_version,
				"server_protocol": server_protocol,
			}
		)
	)
	# Acknowledge before the server disconnects, so the explanation reaches the client first.
	_send(1, {"t": "refused_ack"})
	if multiplayer == Net.multiplayer:
		Net.report_refusal(refusal_reason, StringName(reason_key(refusal_reason).to_lower()), details)
	refused.emit(refusal_reason, protocol_version, server_protocol)


func _refusal_details(reply: Dictionary) -> Dictionary:
	match refusal_reason:
		Net.RefusalReason.WRONG_VERSION:
			var server_version: String = str(reply.get("server_version", "unknown"))
			return {
				"server_version": server_version,
				"client_version": game_version,
				"older": older_side(game_version, server_version),
			}
		Net.RefusalReason.CONTENT_MISMATCH:
			return {}
		Net.RefusalReason.SERVER_FULL:
			return {
				"players": _int_field(reply, "players", 0),
				"max_players": _int_field(reply, "max_players", max_players),
			}
	return {"text": str(reply.get("text", ""))}


func _refusal_text(server_protocol: int, details: Dictionary) -> String:
	match refusal_reason:
		Net.RefusalReason.WRONG_VERSION:
			return (
				"Cannot join: your game is %s (protocol %d), but the server uses %s (protocol %d)."
				% [game_version, protocol_version, details.get("server_version", "unknown"), server_protocol]
			)
		Net.RefusalReason.CONTENT_MISMATCH:
			return "Cannot join: your game content differs from the server's. Use the same content on both PCs."
		Net.RefusalReason.SERVER_FULL:
			return "Cannot join: the server is full."
	var text: String = str(details.get("text", ""))
	return "Cannot join: %s" % text if not text.is_empty() else "Cannot join this server."


## "client" or "server" when both are releases (X.Y.Z or X.Y.Z-test.N) and one is older.
## Empty for dev and editor builds, which have no order.
static func older_side(client_version: String, server_version: String) -> String:
	var release: RegEx = RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+(-test\\.\\d+)?$")
	if release.search(client_version) == null or release.search(server_version) == null:
		return ""
	match Build.compare_versions(client_version, server_version):
		-1:
			return "client"
		1:
			return "server"
	return ""


## The RefusalReason name for a wire code, or "REFUSED" for a code this build does not know.
static func reason_key(code: int) -> String:
	if code < 0 or code >= Net.RefusalReason.size():
		return "REFUSED"
	return Net.RefusalReason.keys()[code]


static func _int_field(message: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = message.get(key)
	if (value is float or value is int) and is_finite(float(value)):
		return int(value)
	return fallback


## A client that loaded another place than the server's switches before its player spawns.
## Peers started outside the menu (tools, tests) have no place and always stay.
func _accept_place(server_place: StringName) -> void:
	var local: bool = multiplayer == Net.multiplayer
	if local and Net.place != &"" and server_place != &"" and server_place != Net.place:
		Log.info(&"net", &"join_switches_place", {"from": String(Net.place), "to": String(server_place)})
		Net.go_to(server_place)
		return
	_scene.complete_auth(1)


func _send(peer_id: int, data: Dictionary) -> void:
	_scene.send_auth(peer_id, JSON.stringify(data).to_utf8_buffer())


func player_level(peer_id: int) -> int:
	return _level if peer_id == multiplayer.get_unique_id() else _levels.get(peer_id, 1)


## The name a player chose for their character, as accepted in the hello.
func player_name(peer_id: int) -> String:
	return _display_name if peer_id == multiplayer.get_unique_id() else _names.get(peer_id, "Survivor")


func _forget_peer(peer_id: int) -> void:
	_levels.erase(peer_id)
	_names.erase(peer_id)
	_accepted.erase(peer_id)
	_rejected.erase(peer_id)

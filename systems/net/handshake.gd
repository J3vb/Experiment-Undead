## Checks the hello before SceneMultiplayer exposes a peer or replicates any players.
class_name Handshake
extends Node

signal accepted(peer_id: int)
signal refused(reason: Net.RefusalReason, client_protocol: int, server_protocol: int)

var protocol_version: int = Build.PROTOCOL_VERSION
var content_hash: String = Build.content_hash
var game_version: String = Build.version
var fingerprint: String = ""
var max_players: int = Net.MAX_PLAYERS
var has_local_player: bool = true
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
	_display_name = display_name
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
		_send(peer_id, ["hello", protocol_version, content_hash, _display_name, _level, game_version, fingerprint])


func _receive_auth(peer_id: int, bytes: PackedByteArray) -> void:
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not data is Array or data.is_empty():
		return
	if multiplayer.is_server():
		if _rejected.has(peer_id) and data == ["refused"]:
			_scene.disconnect_peer(peer_id)
		elif not _accepted.has(peer_id) and not _rejected.has(peer_id):
			_receive_hello(peer_id, data)
	elif peer_id == 1:
		_receive_reply(data)


func _receive_hello(peer_id: int, data: Array) -> void:
	if data.size() != 7 or data[0] != "hello" or not data[1] is float or not data[2] is String:
		return
	var remote_protocol: int = int(data[1])
	if remote_protocol != protocol_version or data[5] != game_version:
		_reject(
			peer_id,
			Net.RefusalReason.WRONG_VERSION,
			remote_protocol,
			{
				"server_version": game_version,
				"client_version": str(data[5]),
			}
		)
	elif data[2] != content_hash or data[6] != fingerprint:
		_reject(peer_id, Net.RefusalReason.CONTENT_MISMATCH, remote_protocol)
	elif _accepted.size() + int(has_local_player) >= max_players:
		_reject(
			peer_id,
			Net.RefusalReason.SERVER_FULL,
			remote_protocol,
			{
				"players": _accepted.size() + int(has_local_player),
				"max_players": max_players,
			}
		)
	else:
		if not data[4] is float or not is_finite(data[4]):
			return
		_levels[peer_id] = clampi(int(data[4]), 1, 50)
		_names[peer_id] = (
			str(data[3]).strip_edges().left(24) if not str(data[3]).strip_edges().is_empty() else "Survivor"
		)
		_accepted[peer_id] = true
		_send(peer_id, ["accepted", String(Net.place)])
		_scene.complete_auth(peer_id)
		accepted.emit(peer_id)


func _reject(peer_id: int, reason: Net.RefusalReason, remote_protocol: int, details: Dictionary = {}) -> void:
	_rejected[peer_id] = true
	_send(peer_id, ["refused", reason, remote_protocol, protocol_version, details])


func _receive_reply(data: Array) -> void:
	if data.size() == 2 and data[0] == "accepted":
		_accept_place(StringName(str(data[1])))
		return
	if data.size() != 5 or data[0] != "refused":
		return
	refusal_reason = int(data[1])
	var client_protocol: int = int(data[2])
	var server_protocol: int = int(data[3])
	var details: Dictionary = data[4]
	refusal_message = _refusal_text(client_protocol, server_protocol, details)
	if refusal_reason == Net.RefusalReason.WRONG_VERSION and client_protocol != server_protocol:
		details["client_version"] = "%s (protocol %d)" % [details.get("client_version", "unknown"), client_protocol]
		details["server_version"] = "%s (protocol %d)" % [details.get("server_version", "unknown"), server_protocol]
	elif refusal_reason == Net.RefusalReason.SERVER_FULL:
		details["players"] = int(details.get("players", 0))
		details["max_players"] = int(details.get("max_players", max_players))
	Net.refusal_reason = refusal_reason
	Net.refusal_message = refusal_message
	(
		Log
		. info(
			&"net",
			&"join_refused",
			{
				"reason": Net.RefusalReason.keys()[refusal_reason],
				"message": refusal_message,
				"client_protocol": client_protocol,
				"server_protocol": server_protocol,
			}
		)
	)
	# Acknowledge before the server disconnects, so the explanation reaches the client first.
	_send(1, ["refused"])
	if multiplayer == Net.multiplayer:
		Net.report_refusal(refusal_reason as Net.RefusalReason, details)
	refused.emit(refusal_reason as Net.RefusalReason, client_protocol, server_protocol)


func _refusal_text(client_protocol: int, server_protocol: int, details: Dictionary) -> String:
	match refusal_reason:
		Net.RefusalReason.WRONG_VERSION:
			return (
				(
					"Cannot join: your game is %s (protocol %d), but the server uses %s (protocol %d). "
					+ "Update both games to the same version."
				)
				% [
					details.get("client_version", "unknown"),
					client_protocol,
					details.get("server_version", "unknown"),
					server_protocol
				]
			)
		Net.RefusalReason.CONTENT_MISMATCH:
			return "Cannot join: your game content differs from the server's. Use the same content on both PCs."
		Net.RefusalReason.SERVER_FULL:
			return "Cannot join: the server is full."
	return "Cannot join this server."


## A client that loaded another place than the server's switches before its player spawns.
## Peers started outside the menu (tools, tests) have no place and always stay.
func _accept_place(server_place: StringName) -> void:
	var local: bool = multiplayer == Net.multiplayer
	if local and Net.place != &"" and server_place != &"" and server_place != Net.place:
		Log.info(&"net", &"join_switches_place", {"from": String(Net.place), "to": String(server_place)})
		Net.go_to(server_place)
		return
	_scene.complete_auth(1)


func _send(peer_id: int, data: Array) -> void:
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

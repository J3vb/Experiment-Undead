## Network role and connection. Solo play is the server with no open port.
## Gameplay that changes shared state (damage, deaths, spawns, points, XP,
## loot) checks Net.is_authority(). See docs/MULTIPLAYER.md.
extends Node

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 8

## "address:port" the next match should join; set by the menu before loading it.
var pending_join: String = ""

var _next_net_id: int = 1


func is_authority() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func host(port: int, max_players: int = MAX_PLAYERS) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, clampi(max_players, 1, MAX_PLAYERS))
	if err == OK:
		multiplayer.multiplayer_peer = peer
		Log.info(&"net", &"hosting", {"port": port, "max_players": max_players})
	return err


func join(address: String) -> Error:
	var target: Array = parse_address(address)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(target[0], target[1])
	if err == OK:
		multiplayer.multiplayer_peer = peer
		Log.info(&"net", &"joining", {"address": target[0], "port": target[1]})
	return err


## Joins pending_join if the menu set one. OK when there is nothing to join.
func start_pending_join() -> Error:
	if pending_join.is_empty():
		return OK
	var address: String = pending_join
	pending_join = ""
	return join(address)


func leave() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


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

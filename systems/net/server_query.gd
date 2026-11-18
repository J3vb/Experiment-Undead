## One round of server browser questions: asks each address on its info port (resolving host
## names without blocking), broadcasts to the LAN, and reports checked replies with their ping.
## The browser calls poll() each frame; nothing here waits.
class_name ServerQuery
extends RefCounted

## address is the asked "host:port", or "ip:port" of a world that answered the LAN broadcast.
signal answered(address: String, info: Dictionary, ping: int, lan: bool)
## Everything not answered by now counts as not responding.
signal timed_out

## Info ports of game ports 7777 to 7784, asked by LAN broadcast.
const LAN_PORTS: PackedInt32Array = [8777, 8778, 8779, 8780, 8781, 8782, 8783, 8784]
const TIMEOUT_MSEC: int = 2000

var lan_ports: PackedInt32Array = LAN_PORTS
var _socket: PacketPeerUDP = PacketPeerUDP.new()
var _nonce: PackedByteArray = PackedByteArray()
var _sent_at: int = 0
var _waiting: bool = false
var _resolving: Dictionary[int, String] = {}
var _asked: Dictionary[String, String] = {}


func _init() -> void:
	_socket.bind(0)


func start(addresses: Array[String]) -> void:
	_forget_names()
	_nonce = Crypto.new().generate_random_bytes(ServerInfo.NONCE_SIZE)
	_sent_at = Time.get_ticks_msec()
	_waiting = true
	_asked.clear()
	for address: String in addresses:
		var parts: Array = ServerAddress.parse(address)
		if parts.is_empty():
			continue
		if str(parts[0]).is_valid_ip_address():
			_send(parts[0], parts[1], address)
		else:
			_resolving[IP.resolve_hostname_queue_item(parts[0])] = address
	ServerInfo.send_queries(_socket, _nonce, lan_ports)


func poll() -> void:
	_poll_names()
	while _socket.get_available_packet_count() > 0:
		var info: Dictionary = ServerInfo.parse_reply(_socket.get_packet(), _nonce)
		if info.is_empty():
			continue
		var source: String = "%s:%d" % [_socket.get_packet_ip(), _socket.get_packet_port() - ServerInfo.PORT_OFFSET]
		answered.emit(_asked.get(source, source), info, Time.get_ticks_msec() - _sent_at, not _asked.has(source))
	if _waiting and Time.get_ticks_msec() - _sent_at > TIMEOUT_MSEC:
		_waiting = false
		timed_out.emit()


func close() -> void:
	_forget_names()
	_socket.close()


func _send(ip: String, port: int, address: String) -> void:
	_asked["%s:%d" % [ip, port]] = address
	ServerInfo.send_queries(_socket, _nonce, PackedInt32Array([port + ServerInfo.PORT_OFFSET]), ip)


func _poll_names() -> void:
	for id: int in _resolving.keys():
		var status: IP.ResolverStatus = IP.get_resolve_item_status(id)
		if status == IP.RESOLVER_STATUS_WAITING:
			continue
		var address: String = _resolving[id]
		var ip: String = IP.get_resolve_item_address(id) if status == IP.RESOLVER_STATUS_DONE else ""
		IP.erase_resolve_item(id)
		_resolving.erase(id)
		if not ip.is_empty():
			_send(ip, ServerAddress.parse(address)[1], address)


func _forget_names() -> void:
	for id: int in _resolving:
		IP.erase_resolve_item(id)
	_resolving.clear()

## Answers server browser info queries on the info port (game port + 1000) while this PC runs a
## world or a dedicated server: name, players, what it is playing, version. Not an ENet message,
## so it works paused and needs no handshake. Also builds and checks the packets for the browser.
class_name ServerInfo
extends Node

const PORT_OFFSET: int = 1000
const QUERY_SIZE: int = 64
const MAX_REPLY: int = 512
const NAME_LENGTH: int = 32
const QUERY_MAGIC: String = "EUQ1"
const REPLY_MAGIC: String = "EUR1"
const NONCE_SIZE: int = 8
## Answers per second, from one address and in total.
const PER_SOURCE: int = 2
const TOTAL: int = 20
## The frozen reply keys and their types; unknown keys are ignored so later versions can add some.
const FIELDS: Dictionary = {
	"name": TYPE_STRING,
	"players": TYPE_FLOAT,
	"max": TYPE_FLOAT,
	"playing": TYPE_STRING,
	"version": TYPE_STRING,
	"protocol": TYPE_FLOAT,
}

var world_name: String = ""
var round_number: int = 0
var _socket: PacketPeerUDP
var _counts: Dictionary[String, int] = {}
var _total: int = 0
var _window: int = 0
var _bad_logged: int = -1000


func _ready() -> void:
	name = "ServerInfo"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(false)
	Events.round_started.connect(func(number: int, _count: int) -> void: round_number = number)
	Net.place_changed.connect(func(_place: StringName) -> void: round_number = 0)


## Binds game_port + 1000. A busy info port only means browsers cannot see this world.
func start(game_port: int, shown_name: String) -> bool:
	stop()
	world_name = shown_name.strip_edges().left(NAME_LENGTH)
	round_number = 0
	_socket = PacketPeerUDP.new()
	if _socket.bind(game_port + PORT_OFFSET) != OK:
		Log.warn(&"net", &"info_port_busy", {"port": game_port + PORT_OFFSET})
		_socket = null
		return false
	set_physics_process(true)
	return true


func stop() -> void:
	if _socket:
		_socket.close()
	_socket = null
	set_physics_process(false)


func is_running() -> bool:
	return _socket != null


func _physics_process(_delta: float) -> void:
	poll()


## One cheap call when nobody asks; answers each good query once, within the caps.
func poll() -> void:
	while _socket and _socket.get_available_packet_count() > 0:
		var packet: PackedByteArray = _socket.get_packet()
		var source: String = _socket.get_packet_ip()
		var source_port: int = _socket.get_packet_port()
		var nonce: PackedByteArray = query_nonce(packet)
		if nonce.is_empty():
			_bad_packet(source)
		elif _allow(source):
			_socket.set_dest_address(source, source_port)
			_socket.put_packet(make_reply(nonce, snapshot()))


func snapshot() -> Dictionary:
	return {
		"name": world_name,
		"players": get_tree().get_nodes_in_group(&"players").size(),
		"max": Net.player_limit,
		"playing": playing(),
		"version": Build.version,
		"protocol": Build.PROTOCOL_VERSION,
	}


## "Lantern Post", "Halcyon Labs, round 12" or "Halcyon Labs, starting".
func playing() -> String:
	var known: bool = Content.has(UI.TYPE, Net.place)
	var data: ScreenData = Content.get_item(UI.TYPE, Net.place) as ScreenData if known else null
	var title: String = data.title if data and not data.title.is_empty() else "Lantern Post"
	if Net.place == DeployVote.HUB or data == null:
		return title
	return "%s, round %d" % [title, round_number] if round_number > 0 else "%s, starting" % title


func _allow(source: String) -> bool:
	var second: int = Time.get_ticks_msec() / 1000
	if second != _window:
		_window = second
		_counts.clear()
		_total = 0
	if _total >= TOTAL or _counts.get(source, 0) >= PER_SOURCE:
		return false
	_counts[source] = _counts.get(source, 0) + 1
	_total += 1
	return true


func _bad_packet(source: String) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _bad_logged >= 1000:
		_bad_logged = now
		Log.warn(&"net", &"info_bad_packet", {"source": source})


## A query: magic, nonce, zero padding to 64 bytes so a reply is never much larger.
static func make_query(nonce: PackedByteArray) -> PackedByteArray:
	var packet: PackedByteArray = QUERY_MAGIC.to_ascii_buffer() + nonce
	packet.resize(QUERY_SIZE)
	return packet


## The nonce of a well-formed query, or an empty array.
static func query_nonce(packet: PackedByteArray) -> PackedByteArray:
	if packet.size() != QUERY_SIZE or packet.slice(0, 4).get_string_from_ascii() != QUERY_MAGIC:
		return PackedByteArray()
	return packet.slice(4, 4 + NONCE_SIZE)


static func make_reply(nonce: PackedByteArray, info: Dictionary) -> PackedByteArray:
	var fields: Dictionary = info.duplicate()
	fields.name = str(fields.get("name", "")).left(NAME_LENGTH)
	return REPLY_MAGIC.to_ascii_buffer() + nonce + JSON.stringify(fields).to_utf8_buffer()


## The checked reply for this nonce, or {} for anything too big, wrong or of the wrong types.
static func parse_reply(packet: PackedByteArray, nonce: PackedByteArray) -> Dictionary:
	var head: int = 4 + NONCE_SIZE
	if packet.size() > MAX_REPLY or packet.size() <= head:
		return {}
	if packet.slice(0, 4).get_string_from_ascii() != REPLY_MAGIC or packet.slice(4, head) != nonce:
		return {}
	var json: JSON = JSON.new()
	if json.parse(packet.slice(head).get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	var info: Dictionary = {}
	for key: String in FIELDS:
		if typeof(data.get(key)) != FIELDS[key]:
			return {}
		info[key] = data[key]
	info.name = str(info.name).left(NAME_LENGTH)
	for key: String in ["players", "max", "protocol"]:
		info[key] = int(info[key])
	return info


## Sends one query to each port at address (the LAN broadcast address by default).
static func send_queries(
	socket: PacketPeerUDP, nonce: PackedByteArray, ports: PackedInt32Array, address: String = "255.255.255.255"
) -> void:
	socket.set_broadcast_enabled(true)
	for port: int in ports:
		socket.set_dest_address(address, port)
		socket.put_packet(make_query(nonce))

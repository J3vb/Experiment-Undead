## Opens the world's game and info ports on the home router with UPnP, in a thread, once per
## game run, and finds the address friends add. Removes the mappings when the game quits.
class_name PortOpener
extends RefCounted

## The router answered (or not); result holds the outcome.
signal finished

const LEASE_SECONDS: int = 3600
const RENEW_SECONDS: float = 3000.0
const INFO_PORT_OFFSET: int = 1000
const DESCRIPTION: String = "Experiment Undead"
## UPNP_RESULT_SUCCESS, named here so a build without the UPNP class still loads.
const SUCCESS: int = 0

## {"router": &"pending" | &"opened" | &"no_router" | &"failed" | &"cgnat", "address": String}.
var result: Dictionary = {}
## Tests set a stand-in with the UPNP methods used here; the game makes a real UPNP per run.
var make_router: Callable = func() -> Object:
	return ClassDB.instantiate(&"UPNP") if ClassDB.class_exists(&"UPNP") else null

var _port: int = 0
var _router: Object
var _thread: Thread
var _renew: SceneTreeTimer


## Maps port and port + 1000 unless they are already mapped this run. Runs in a thread.
func open(port: int) -> void:
	if port == _port and result.get("router", &"") in [&"pending", &"opened"]:
		return
	close()
	_port = port
	result = {"router": &"pending", "address": ""}
	_thread = Thread.new()
	_thread.start(_run.bind(port))


## Quitting the game: waits for a running discovery, then removes both mappings.
func close() -> void:
	if _thread:
		_thread.wait_to_finish()
		_thread = null
	if _renew and _renew.timeout.is_connected(_on_renew):
		_renew.timeout.disconnect(_on_renew)
	_renew = null
	if _router and result.get("router", &"") == &"opened":
		for mapped: int in [_port, _port + INFO_PORT_OFFSET]:
			_router.call(&"delete_port_mapping", mapped, "UDP")
	_router = null
	_port = 0
	result = {}


## The whole router conversation, also called directly by tests. Returns the result.
func map(port: int) -> Dictionary:
	_router = make_router.call()
	if _router == null or _router.call(&"discover") != SUCCESS:
		return {"router": &"no_router", "address": local_address()}
	var gateway: Object = _router.call(&"get_gateway")
	if gateway == null or not gateway.call(&"is_valid_gateway"):
		return {"router": &"no_router", "address": local_address()}
	if not _add_mapping(port):
		return {"router": &"failed", "address": local_address()}
	if not _add_mapping(port + INFO_PORT_OFFSET):
		_router.call(&"delete_port_mapping", port, "UDP")
		return {"router": &"failed", "address": local_address()}
	var external: String = str(_router.call(&"query_external_address"))
	if external.is_empty() or is_private(external):
		return {"router": &"cgnat", "address": local_address()}
	return {"router": &"opened", "address": external}


## Some routers refuse a lease time; those get a mapping with no expiry instead.
func _add_mapping(port: int) -> bool:
	if _router.call(&"add_port_mapping", port, port, DESCRIPTION, "UDP", LEASE_SECONDS) == SUCCESS:
		return true
	return _router.call(&"add_port_mapping", port, port, DESCRIPTION, "UDP", 0) == SUCCESS


func _run(port: int) -> void:
	_finish.call_deferred(port, map(port))


func _finish(port: int, outcome: Dictionary) -> void:
	if _thread:
		_thread.wait_to_finish()
		_thread = null
	if port != _port:
		return
	result = outcome
	match result.router:
		&"opened":
			Log.info(&"net", &"upnp_opened", {"port": port})
			_renew = (Engine.get_main_loop() as SceneTree).create_timer(RENEW_SECONDS, true, false, true)
			_renew.timeout.connect(_on_renew)
		&"cgnat":
			Log.warn(&"net", &"upnp_cgnat", {"port": port})
		_:
			Log.warn(&"net", &"upnp_failed", {"port": port, "reason": String(result.router)})
	finished.emit()


## The lease runs out after an hour; map again while the world stays open.
func _on_renew() -> void:
	_renew = null
	_thread = Thread.new()
	_thread.start(_run.bind(_port))


## Addresses an internet friend cannot reach: private ranges and the provider-shared 100.64.0.0/10.
static func is_private(address: String) -> bool:
	var parts: PackedStringArray = address.split(".")
	if parts.size() != 4:
		return true
	var first: int = parts[0].to_int()
	var second: int = parts[1].to_int()
	return (
		first == 10
		or first == 127
		or (first == 172 and second >= 16 and second <= 31)
		or (first == 192 and second == 168)
		or (first == 100 and second >= 64 and second <= 127)
	)


## This PC's first private IPv4 address, for friends on the same network.
static func local_address() -> String:
	for address: String in IP.get_local_addresses():
		if address.count(".") == 3 and is_private(address) and not address.begins_with("127."):
			return address
	return "127.0.0.1"

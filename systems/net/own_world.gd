## This PC's own world (Enter world): a listen server on the saved port, so friends can join
## from their server browser, or offline when they cannot. Net holds the one instance; it also
## owns the router mapping (PortOpener), which lasts the whole game run.
class_name OwnWorld
extends RefCounted

## The router answered while the world is open; the pause screen redraws its line.
signal changed

## {"status": &"open" | &"offline_busy" | &"offline_off", "port": int}, and while open
## "router" (PortOpener result or &"off") and "address" friends add. Empty when this PC runs
## no world of its own (the main menu, or a friend's game).
var state: Dictionary = {}
var ports: PortOpener = PortOpener.new()


func _init() -> void:
	ports.finished.connect(_on_router)


func open(port: int) -> void:
	state = {"status": &"offline_off", "port": port}
	if not Settings.get_value(&"network", &"open_to_friends"):
		return
	if Net.host(port) != OK:
		Net.last_error.clear()
		Log.warn(&"net", &"port_busy", {"port": port})
		state.status = &"offline_busy"
		return
	state.status = &"open"
	if not Settings.get_value(&"network", &"upnp"):
		state.merge({"router": &"off", "address": PortOpener.local_address()})
		return
	ports.open(port)
	state.merge(ports.result, true)


## Restart while alone: the reloaded match keeps the world's port open (start_pending_join
## clears the flag in the new session).
func reload() -> void:
	Net.changing_place = Net.is_online() and Net.multiplayer.is_server()
	UI.reload()


func close() -> void:
	state = {}


## The game is quitting: give the router its ports back.
func quit() -> void:
	ports.close()


func _on_router() -> void:
	if state.get("status") == &"open" and state.get("router") != &"off":
		state.merge(ports.result, true)
		changed.emit()

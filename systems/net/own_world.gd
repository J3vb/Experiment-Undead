## This PC's own world (Enter world): a listen server on the saved port, so friends can join
## from their server browser, or offline when they cannot. Net holds the one instance.
class_name OwnWorld
extends RefCounted

## {"status": &"open" | &"offline_busy" | &"offline_off", "port": int}; empty when this PC
## runs no world of its own (the main menu, or a friend's game).
var state: Dictionary = {}


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


## Restart while alone: the reloaded match keeps the world's port open (start_pending_join
## clears the flag in the new session).
func reload() -> void:
	Net.changing_place = Net.is_online() and Net.multiplayer.is_server()
	UI.reload()


func close() -> void:
	state = {}

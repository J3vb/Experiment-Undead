## Shared plain-word network errors and a cancellable connection overlay.
class_name NetErrorDialog
extends CanvasLayer

signal closed

const MESSAGES: Dictionary = {
	&"bad_address": "That address doesn't look right. Use something like 192.168.1.20:7777.",
	&"invalid_port": "Use a port number from 1 to 65535.",
	&"content_mismatch": "Your game files differ from the server's. Update or verify the game.",
	&"lost_connection": "Lost connection to the server.",
	&"host_ended": "The host ended the match.",
}

var connecting: bool = false

@onready var message_label: Label = $Root/Center/Panel/Box/Message
@onready var action_button: Button = $Root/Center/Panel/Box/Action
@onready var update_button: Button = $Root/Center/Panel/Box/Update


func _ready() -> void:
	hide()
	visibility_changed.connect(func() -> void: UI.hold_mouse(self, visible))
	action_button.pressed.connect(_dismiss)
	update_button.pressed.connect(_restart_to_update)
	Net.join_started.connect(_on_join_started)
	Net.join_succeeded.connect(_on_join_succeeded)
	Net.connection_error.connect(_on_connection_error)
	get_tree().scene_changed.connect(_on_scene_changed)


static func message_for(reason: StringName, details: Dictionary = {}) -> String:
	match reason:
		&"timeout":
			return "Couldn't reach %s. Check the address and that the server is running." % details.get("address", "")
		&"port_in_use":
			return "Port %d is already in use. Close the other server or pick another port." % details.get("port", 7777)
		&"server_full":
			return "The server is full (%d of %d players)." % [details.get("players", 8), details.get("max_players", 8)]
		&"wrong_version":
			return _version_text(details)
		&"refused":
			var text: String = str(details.get("text", ""))
			return text if not text.is_empty() else "The server refused to let you join."
	return MESSAGES.get(reason, "Couldn't connect to the server. Try again.")


## Names the side to update; dev builds have no order, so they only hear "different builds".
static func _version_text(details: Dictionary) -> String:
	var client: String = str(details.get("client_version", ""))
	var server: String = str(details.get("server_version", ""))
	match details.get("older", ""):
		"client":
			return "Your game is v%s, the server runs v%s. Update your game, then join again." % [client, server]
		"server":
			return "The server runs v%s, your game is v%s. The host needs to update the server." % [server, client]
	return "Your game and the server are different builds. Use the same build on both."


func show_error(reason: StringName, details: Dictionary = {}) -> void:
	connecting = false
	message_label.text = message_for(reason, details)
	update_button.visible = can_update(reason, details, launcher_exe(OS.get_cmdline_args()))
	action_button.text = "OK"
	show()
	action_button.grab_focus()


## "Your game is older" and the game was started by the separate launcher, which can update it.
static func can_update(reason: StringName, details: Dictionary, launcher: String) -> bool:
	return (
		reason == &"wrong_version"
		and details.get("older", "") == "client"
		and not launcher.is_empty()
		and FileAccess.file_exists(launcher)
	)


## The launcher exe that started this game (--launcher-exe=<path>), or "".
static func launcher_exe(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.begins_with("--launcher-exe="):
			return arg.trim_prefix("--launcher-exe=")
	return ""


## Starts the launcher, which installs the newer version, and quits.
func _restart_to_update() -> void:
	if OS.create_process(launcher_exe(OS.get_cmdline_args()), PackedStringArray()) >= 0:
		get_tree().quit()


func show_connecting(address: String) -> void:
	connecting = true
	update_button.hide()
	message_label.text = "Connecting to %s..." % address
	action_button.text = "Cancel"
	show()
	_on_scene_changed()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss()


func _dismiss() -> void:
	if not connecting:
		hide()
		closed.emit()
		return
	Net.pending_join = ""
	Net.leave()
	UI.replace(&"main_menu")
	queue_free()


func _on_join_started(address: String) -> void:
	if connecting:
		show_connecting(address)


func _on_join_succeeded() -> void:
	if connecting:
		queue_free()


func _on_connection_error(_reason: StringName, _details: Dictionary) -> void:
	if connecting:
		queue_free()


func _on_scene_changed() -> void:
	if visible and not is_queued_for_deletion():
		action_button.grab_focus()

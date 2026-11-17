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


func _ready() -> void:
	hide()
	visibility_changed.connect(func() -> void: UI.hold_mouse(self, visible))
	action_button.pressed.connect(_dismiss)
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
			return (
				"Different game version. Server: %s, you: %s. Update the game to join."
				% [details.get("server_version", ""), details.get("client_version", "")]
			)
	return MESSAGES.get(reason, "Couldn't connect to the server. Try again.")


func show_error(reason: StringName, details: Dictionary = {}) -> void:
	connecting = false
	message_label.text = message_for(reason, details)
	action_button.text = "OK"
	show()
	action_button.grab_focus()


func show_connecting(address: String) -> void:
	connecting = true
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

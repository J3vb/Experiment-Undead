## Exact network error copy and modal keyboard/controller behavior.
extends GutTest

const DIALOG: PackedScene = preload("res://systems/ui/net_error_dialog.tscn")

var dialog: NetErrorDialog


func before_each() -> void:
	dialog = DIALOG.instantiate() as NetErrorDialog
	add_child_autofree(dialog)


func test_bad_address_text() -> void:
	assert_eq(
		NetErrorDialog.message_for(&"bad_address"),
		"That address doesn't look right. Use something like 192.168.1.20:7777."
	)


func test_timeout_text() -> void:
	assert_eq(
		NetErrorDialog.message_for(&"timeout", {"address": "1.2.3.4:7777"}),
		"Couldn't reach 1.2.3.4:7777. Check the address and that the server is running."
	)


func test_invalid_port_text() -> void:
	assert_eq(NetErrorDialog.message_for(&"invalid_port"), "Use a port number from 1 to 65535.")


func test_port_in_use_text() -> void:
	assert_eq(
		NetErrorDialog.message_for(&"port_in_use", {"port": 7777}),
		"Port 7777 is already in use. Close the other server or pick another port."
	)


func test_full_server_text() -> void:
	assert_eq(
		NetErrorDialog.message_for(&"server_full", {"players": 8, "max_players": 8}),
		"The server is full (8 of 8 players)."
	)


func test_older_client_is_told_to_update_the_game() -> void:
	assert_eq(
		NetErrorDialog.message_for(
			&"wrong_version", {"server_version": "0.1.1", "client_version": "0.1.0", "older": "client"}
		),
		"Your game is v0.1.0, the server runs v0.1.1. Update your game, then join again."
	)


func test_older_server_is_named_for_the_host() -> void:
	assert_eq(
		NetErrorDialog.message_for(
			&"wrong_version", {"server_version": "0.1.0", "client_version": "0.1.1", "older": "server"}
		),
		"The server runs v0.1.0, your game is v0.1.1. The host needs to update the server."
	)


func test_dev_builds_are_only_called_different() -> void:
	assert_eq(
		NetErrorDialog.message_for(
			&"wrong_version", {"server_version": "0.1.0-dev.4+abc", "client_version": "dev", "older": ""}
		),
		"Your game and the server are different builds. Use the same build on both."
	)


func test_unknown_refusal_shows_the_server_text() -> void:
	assert_eq(NetErrorDialog.message_for(&"refused", {"text": "Closed for maintenance."}), "Closed for maintenance.")
	assert_eq(NetErrorDialog.message_for(&"refused"), "The server refused to let you join.")


func test_content_mismatch_text() -> void:
	assert_eq(
		NetErrorDialog.message_for(&"content_mismatch"),
		"Your game files differ from the server's. Update or verify the game."
	)


func test_lost_connection_text() -> void:
	assert_eq(NetErrorDialog.message_for(&"lost_connection"), "Lost connection to the server.")


func test_host_ended_text() -> void:
	assert_eq(NetErrorDialog.message_for(&"host_ended"), "The host ended the match.")


func test_error_opens_with_focus_and_acknowledges() -> void:
	assert_false(dialog.visible)
	dialog.show_error(&"lost_connection")
	assert_eq(dialog.message_label.text, "Lost connection to the server.")
	assert_true(dialog.action_button.has_focus())
	assert_eq(dialog.action_button.text, "OK")
	watch_signals(dialog)
	dialog.action_button.pressed.emit()
	assert_false(dialog.visible)
	assert_signal_emitted(dialog, "closed")


func test_connection_shows_target_and_traps_focus() -> void:
	dialog.show_connecting("1.2.3.4:7777")
	assert_eq(dialog.message_label.text, "Connecting to 1.2.3.4:7777...")
	assert_eq(dialog.action_button.text, "Cancel")
	assert_true(dialog.action_button.has_focus())
	assert_eq(dialog.action_button.get_node(dialog.action_button.focus_next), dialog.action_button)
	assert_eq(dialog.action_button.get_node(dialog.action_button.focus_previous), dialog.action_button)
	assert_eq(dialog.action_button.get_node(dialog.action_button.focus_neighbor_left), dialog.action_button)
	assert_eq(dialog.action_button.get_node(dialog.action_button.focus_neighbor_right), dialog.action_button)


func test_cancel_key_acknowledges_error() -> void:
	dialog.show_error(&"content_mismatch")
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	dialog._input(cancel)
	assert_false(dialog.visible)


func test_visible_error_restores_focus_after_scene_replacement() -> void:
	dialog.show_error(&"timeout", {"address": "1.2.3.4:7777"})
	dialog.action_button.release_focus()
	dialog._on_scene_changed()
	assert_true(dialog.action_button.has_focus())
	dialog.hide()
	dialog.action_button.release_focus()
	dialog._on_scene_changed()
	assert_false(dialog.action_button.has_focus(), "a hidden dialog never takes focus")


func test_visible_dialog_holds_the_mouse_until_hidden() -> void:
	var root: ScreenData = UI._root
	UI._root = Content.get_item(&"screens", &"match") as ScreenData
	assert_false(UI.mouse_should_be_free())
	dialog.show_error(&"lost_connection")
	assert_true(UI.mouse_should_be_free(), "an error over the match frees the mouse")
	dialog.hide()
	assert_false(UI.mouse_should_be_free())
	dialog.show_connecting("1.2.3.4:7777")
	assert_true(UI.mouse_should_be_free(), "the connecting overlay frees the mouse")
	dialog._on_join_succeeded()
	await wait_process_frames(2)
	assert_false(UI.mouse_should_be_free(), "a successful join gives the mouse back to the match")
	UI._root = root

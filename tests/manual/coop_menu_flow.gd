## Real menu scene transitions, deadline and cancellation in an isolated process.
extends SceneTree

const MENU_SCENE: String = "res://systems/ui/main_menu.tscn"
## Join and Host and play land in the hub (F-47 step 4).
const SESSION_SCENE: String = "res://systems/game/hub_session.tscn"
const TARGET: String = "127.0.0.1:24659"
const HOST_PORT: int = 24658

var _failures: Array[String] = []
var _result_path: String = ""
var _mode: String = "timeout"
var _settings: Node
var _net: Node


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--result="):
			_result_path = argument.trim_prefix("--result=")
	node_added.connect(_disable_profile)
	_run.call_deferred()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void: _finish("watchdog expired"))
	_settings = root.get_node("Settings")
	_net = root.get_node("Net")
	_settings.config_path = "user://test_coop_menu_%s.cfg" % _mode
	_settings.reset_to_defaults()
	var menu_script: GDScript = load("res://systems/ui/main_menu.gd")
	menu_script.launch_consumed = true
	change_scene_to_file(MENU_SCENE)
	await _settle()
	match _mode:
		"timeout":
			await _timeout_flow()
		"cancel":
			await _cancel_flow()
		"host":
			await _host_flow()
		_:
			_failures.append("Unknown mode: " + _mode)
	_finish()


func _timeout_flow() -> void:
	var started: int = Time.get_ticks_msec()
	# The deadline is when Net gives up; loading the menu afterwards is not part of it
	# (the hub does not load the Halcyon Labs map, so the menu loads it cold).
	var timed_out_at: Array[int] = [-1]
	_net.connection_error.connect(
		func(_reason: StringName, _details: Dictionary) -> void: timed_out_at[0] = Time.get_ticks_msec(),
		CONNECT_ONE_SHOT
	)
	await _start_join()
	if current_scene.scene_file_path != SESSION_SCENE:
		_failures.append("Join did not enter the hub scene")
		return
	_check_connecting()
	while Time.get_ticks_msec() - started < 8000 and current_scene.scene_file_path == SESSION_SCENE:
		await process_frame
	await _settle()
	if current_scene.scene_file_path != MENU_SCENE:
		_failures.append("No menu timeout within seven seconds")
		return
	var menu: Control = current_scene as Control
	_check(timed_out_at[0] > 0 and timed_out_at[0] - started < 7000, "Timeout arrived within seven seconds")
	_check(menu.error_dialog.visible, "Timeout dialog is visible")
	_check(menu.error_dialog.action_button.has_focus(), "Timeout action has focus")
	_check(
		(
			menu.error_dialog.message_label.text
			== "Couldn't reach 127.0.0.1:24659. Check the address and that the server is running."
		),
		"Timeout says the exact address and plain-word error"
	)
	_check(not _net.is_online(), "Timeout closed the connection")
	menu.error_dialog.action_button.pressed.emit()
	_settings.load_settings()
	menu.join_button.pressed.emit()
	_check(menu.address_field.text == TARGET, "The next menu remembers the persisted address")


func _cancel_flow() -> void:
	await _start_join()
	if current_scene.scene_file_path != SESSION_SCENE:
		_failures.append("Join did not enter the hub scene")
		return
	_check_connecting()
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await _settle()
	cancel.pressed = false
	Input.parse_input_event(cancel)
	await create_timer(6.2).timeout
	if current_scene.scene_file_path != MENU_SCENE:
		_failures.append("Cancel did not return to the menu")
		return
	var menu: Control = current_scene as Control
	_check(not _net.is_online(), "Cancel closed the pending connection")
	_check(not _net.joining, "Cancel cleared the joining state")
	_check(not menu.error_dialog.visible, "The cancelled deadline never opens an error")
	_check(_net.last_error.is_empty(), "Cancel leaves no pending failure")


func _host_flow() -> void:
	var menu: Control = current_scene as Control
	menu.host_button.pressed.emit()
	_check(menu.port_field.has_focus(), "Host starts on its port field")
	menu.port_field.text = str(HOST_PORT)
	(menu.get_node("Screens/Root/HostPanel/Box/Start") as Button).pressed.emit()
	await _settle()
	if current_scene.scene_file_path != SESSION_SCENE:
		_failures.append("Host did not enter the hub scene")
		return
	_check(_net.is_online() and _net.is_authority(), "Host opens a listen server")
	_check(_net.pending_join.is_empty(), "Host has no pending client join")
	var pause: InputEventAction = InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	current_scene.call("_unhandled_input", pause)
	var ui: Node = root.get_node("UI")
	var pause_layer: Node = ui.get_child(ui.get_child_count() - 1)
	(pause_layer.get_node("PauseScreen/Menu/MainMenu") as Button).pressed.emit()
	await _settle()
	if current_scene.scene_file_path != MENU_SCENE:
		_failures.append("The match menu did not return to the main menu")
		return
	menu = current_scene as Control
	_check(not paused, "Returning from a hosted match clears pause")
	_check(not _net.is_online(), "Returning closes the hosted port")
	_settings.load_settings()
	menu.host_button.pressed.emit()
	_check(menu.port_field.text == str(HOST_PORT), "Host remembers the persisted port")
	_check(not menu.error_dialog.visible, "The host sees no disconnect error")


func _start_join() -> void:
	var menu: Control = current_scene as Control
	menu.join_button.pressed.emit()
	menu.address_field.text = TARGET
	(menu.get_node("Screens/Root/JoinPanel/Box/Connect") as Button).pressed.emit()
	await _settle()


func _check_connecting() -> void:
	var overlay: CanvasLayer = root.get_node_or_null("NetErrorDialog") as CanvasLayer
	if overlay == null:
		_failures.append("The connecting overlay survives the scene transition")
		return
	_check(overlay.visible and overlay.connecting, "The connecting overlay is active")
	_check(overlay.message_label.text == "Connecting to 127.0.0.1:24659...", "Connecting shows the target")
	_check(overlay.action_button.text == "Cancel", "Connecting offers Cancel")
	_check(overlay.action_button.has_focus(), "Cancel has keyboard and controller focus")


## Waits out a threaded load behind the loading screen, then lets the scene change land.
func _settle() -> void:
	var ui: Node = root.get_node("UI")
	var started: int = Time.get_ticks_msec()
	await process_frame
	while ui.call(&"is_loading") and Time.get_ticks_msec() - started < 10000:
		await process_frame
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(extra_failure: String = "") -> void:
	if not extra_failure.is_empty():
		_failures.append(extra_failure)
	if not _result_path.is_empty():
		var result: FileAccess = FileAccess.open(_result_path, FileAccess.WRITE)
		if result:
			result.store_string(JSON.stringify({"mode": _mode, "failures": _failures}))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_settings.config_path))
	if _failures.is_empty():
		print("Co-op menu %s flow passed" % _mode)
	else:
		printerr("Co-op menu %s failures: %s" % [_mode, _failures])
	quit(0 if _failures.is_empty() else 1)


func _disable_profile(node: Node) -> void:
	var script: Script = node.get_script() as Script
	if script and script.resource_path == "res://systems/game/game_session.gd":
		node.set("profile_id", &"")

## Standalone scene transitions: run headless with --script res://tests/manual/main_menu_flow.gd.
extends SceneTree


func _initialize() -> void:
	node_added.connect(_disable_profile)
	_run.call_deferred()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void: quit(1))
	change_scene_to_file("res://systems/ui/main_menu.tscn")
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://systems/ui/main_menu.tscn")
	var down: InputEventJoypadButton = InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	assert((current_scene.get_node("Screens/Root/Menu/Settings") as Button).has_focus())
	down.pressed = false
	Input.parse_input_event(down)
	await _press_action(&"ui_accept")
	assert((current_scene.get_node("Screens/Root/SettingsScreen") as Control).visible)
	await _press_action(&"ui_cancel")
	assert((current_scene.get_node("Screens/Root/Menu/Settings") as Button).has_focus())
	(current_scene.get_node("Screens/Root/Menu/Play") as Button).pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://systems/game/game_session.tscn")
	current_scene.call("_set_paused", true)
	assert(paused)
	(current_scene.get_node("Hud/Root/PausePanel/Menu/MainMenu") as Button).pressed.emit()
	await process_frame
	await process_frame
	assert(not paused)
	assert(current_scene.scene_file_path == "res://systems/ui/main_menu.tscn")
	await _results_flow()
	print("Main menu flow passed: controller settings/back, Play, pause/menu, results/restart/menu, Quit")
	(current_scene.get_node("Screens/Root/Menu/Quit") as Button).pressed.emit()


func _results_flow() -> void:
	(current_scene.get_node("Screens/Root/Menu/Play") as Button).pressed.emit()
	await process_frame
	await process_frame
	current_scene.set("is_over", true)
	current_scene.get_node("Hud").call("_on_game_over", {"round": 1})
	var restart_key: InputEventKey = InputEventKey.new()
	restart_key.physical_keycode = KEY_R
	restart_key.pressed = true
	Input.parse_input_event(restart_key)
	await process_frame
	await process_frame
	assert(not bool(current_scene.get("is_over")))
	restart_key.pressed = false
	Input.parse_input_event(restart_key)
	current_scene.set("is_over", true)
	current_scene.get_node("Hud").call("_on_game_over", {"round": 1})
	await _press_action(&"ui_cancel")
	assert(current_scene.scene_file_path == "res://systems/ui/main_menu.tscn")


func _press_action(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _disable_profile(node: Node) -> void:
	var script: Script = node.get_script() as Script
	if script and script.resource_path == "res://systems/game/game_session.gd":
		node.set("profile_id", &"")

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
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	assert((current_scene.get_node("Screens/Root/Menu/Servers") as Button).has_focus())
	await _press_action(&"ui_accept")
	assert((current_scene.get_node("Screens/Root/JoinPanel/Box/Address") as LineEdit).has_focus())
	await _press_action(&"ui_cancel")
	assert((current_scene.get_node("Screens/Root/Menu/Servers") as Button).has_focus())
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	assert((current_scene.get_node("Screens/Root/Menu/Loadout") as Button).has_focus())
	await _character_flow()
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	assert((current_scene.get_node("Screens/Root/Menu/Settings") as Button).has_focus())
	await _press_action(&"ui_accept")
	assert((current_scene.get_node("Screens/Root/SettingsScreen") as Control).visible)
	await _press_action(&"ui_cancel")
	assert((current_scene.get_node("Screens/Root/Menu/Settings") as Button).has_focus())
	(current_scene.get_node("Screens/Root/Menu/EnterWorld") as Button).pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://systems/game/hub_session.tscn")
	var pause: InputEventAction = InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	current_scene.call("_unhandled_input", pause)
	var ui: Node = root.get_node("UI")
	var pause_layer: Node = ui.get_child(ui.get_child_count() - 1)
	assert(paused)
	(pause_layer.get_node("PauseScreen/Menu/MainMenu") as Button).pressed.emit()
	await process_frame
	await process_frame
	assert(not paused)
	assert(current_scene.scene_file_path == "res://systems/ui/main_menu.tscn")
	await _results_flow()
	print(
		"Main menu flow passed: controller Servers/Loadout/Settings/back, Enter World, pause/menu, results/restart/menu, Exit"
	)
	(current_scene.get_node("Screens/Root/Menu/Quit") as Button).pressed.emit()


func _results_flow() -> void:
	(current_scene.get_node("Screens/Root/Menu/EnterWorld") as Button).pressed.emit()
	await process_frame
	await process_frame
	current_scene.set("restart_delay", 0.0)
	current_scene.get_node("MatchEnd").call("_receive_match_end", {"round": 1})
	await process_frame
	await process_frame
	var restart_key: InputEventKey = InputEventKey.new()
	restart_key.physical_keycode = KEY_R
	restart_key.pressed = true
	Input.parse_input_event(restart_key)
	await process_frame
	await process_frame
	assert(not bool(current_scene.get("is_over")))
	restart_key.pressed = false
	Input.parse_input_event(restart_key)
	current_scene.set("restart_delay", 0.0)
	current_scene.get_node("MatchEnd").call("_receive_match_end", {"round": 1})
	await process_frame
	await process_frame
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


func _character_flow() -> void:
	await _press_action(&"ui_accept")
	var character: Control = current_scene.get("character_screen") as Control
	assert(character != null)
	assert(character.is_ancestor_of(root.gui_get_focus_owner()))
	var profile: RefCounted = character.get("profile") as RefCounted
	profile.set("id", &"test_main_menu_character")
	await _press_joypad_button(JOY_BUTTON_B)
	assert(current_scene.get("character_screen") == null)
	assert((current_scene.get_node("Screens/Root/Menu/Character") as Button).has_focus())
	var profiles: Script = load("res://systems/progression/character_profile.gd")
	var path: String = str(profiles.call("directory")) + "test_main_menu_character.json"
	assert(FileAccess.file_exists(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _press_joypad_button(button: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
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

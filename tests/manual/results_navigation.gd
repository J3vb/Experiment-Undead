## Standalone input check: --headless --script res://tests/manual/results_navigation.gd.
extends SceneTree

var screen: Control
var menus: int = 0
var restarts: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(10.0).timeout.connect(func() -> void: quit(1))
	screen = load("res://systems/ui/results_screen.tscn").instantiate() as Control
	root.add_child(screen)
	screen.main_menu_requested.connect(func() -> void: menus += 1)
	screen.restart_requested.connect(func() -> void: restarts += 1)
	screen.show_results({})
	await process_frame
	assert(screen.main_menu_button.has_focus())
	await _press_controller(JOY_BUTTON_DPAD_DOWN)
	assert(screen.restart_button.has_focus())
	await _press_controller(JOY_BUTTON_A)
	assert(restarts == 1)
	await _press_key(KEY_TAB)
	assert(screen.main_menu_button.has_focus())
	await _press_key(KEY_ENTER)
	assert(menus == 1)
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = screen.restart_button.get_global_rect().get_center()
	mouse.global_position = mouse.position
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await process_frame
	mouse.pressed = false
	Input.parse_input_event(mouse)
	await process_frame
	assert(restarts == 2)
	await _press_key(KEY_R)
	assert(restarts == 3)
	await _press_controller(JOY_BUTTON_B)
	assert(menus == 2)
	await _press_key(KEY_ESCAPE)
	assert(menus == 3)
	print("Results navigation passed: controller, keyboard, mouse, R restart and Esc/B menu")
	quit()


func _press_controller(button: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _press_key(key: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

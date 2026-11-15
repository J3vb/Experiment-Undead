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
	await _test_loot_navigation()
	print("Results navigation passed: controller, keyboard, mouse, six-card scrolling, R restart and Esc/B menu")
	quit()


func _test_loot_navigation() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var items: Array[Dictionary] = []
	for level: int in range(6, 0, -1):
		items.append({"base": "rifle_ar", "rar": "rare", "ilvl": level})
	screen.show_results({"loot": items})
	await create_timer(0.2).timeout
	assert(screen.size == Vector2(1280, 720))
	var last: Control = screen.loot_items.get_child(5) as Control
	assert(last.get_global_rect().end.y > screen.loot_scroll.get_global_rect().end.y)
	await _press_controller(JOY_BUTTON_DPAD_LEFT)
	assert(screen.loot_items.get_child(0).has_focus())
	for index: int in range(5):
		await _press_controller(JOY_BUTTON_DPAD_DOWN)
	_assert_last_card_visible(last)
	await _press_controller(JOY_BUTTON_DPAD_RIGHT)
	assert(screen.main_menu_button.has_focus())
	await _press_key(KEY_LEFT)
	assert(screen.loot_items.get_child(0).has_focus())
	for index: int in range(5):
		await _press_key(KEY_TAB)
	_assert_last_card_visible(last)
	await _press_key(KEY_TAB)
	assert(screen.main_menu_button.has_focus())
	await _press_key(KEY_R)
	assert(restarts == 4)
	screen.show_results({"loot": items})
	await process_frame
	assert(screen.main_menu_button.has_focus())
	assert(screen.loot_scroll.scroll_vertical == 0)
	screen.show_results({})
	await process_frame
	await _press_controller(JOY_BUTTON_DPAD_DOWN)
	assert(screen.restart_button.has_focus())
	await _press_key(KEY_TAB)
	assert(screen.main_menu_button.has_focus())


func _assert_last_card_visible(last: Control) -> void:
	assert(last.has_focus())
	assert(screen.loot_scroll.scroll_vertical > 0)
	assert(last.get_global_rect().position.y >= screen.loot_scroll.get_global_rect().position.y - 1.0)
	assert(last.get_global_rect().end.y <= screen.loot_scroll.get_global_rect().end.y + 1.0)


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

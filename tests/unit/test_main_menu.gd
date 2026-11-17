## Front-end focus, co-op validation, remembered addresses and shared panels.
extends GutTest

const MENU: PackedScene = preload("res://systems/ui/main_menu.tscn")
const SETTINGS_PATH: String = "user://test_main_menu_settings.cfg"

var menu: MainMenu
var _settings_path: String
var _settings_values: Dictionary


func before_each() -> void:
	_settings_path = Settings.config_path
	_settings_values = Settings._values.duplicate(true)
	Settings.config_path = SETTINGS_PATH
	Settings.reset_to_defaults()
	Net.last_error.clear()
	Net.pending_join = ""
	menu = MENU.instantiate() as MainMenu
	add_child_autofree(menu)


func after_each() -> void:
	while UI.top() != &"":
		UI.pop()
	Settings._values = _settings_values
	Settings.config_path = _settings_path
	Settings._apply_all()
	Net.last_error.clear()
	Net.pending_join = ""
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func test_play_has_default_focus_and_existing_match_target() -> void:
	assert_true(menu.play_button.has_focus())
	var match_screen: ScreenData = Content.get_item(&"screens", &"match") as ScreenData
	assert_true(ResourceLoader.exists(match_screen.scene))
	assert_eq(match_screen.scene, "res://systems/game/game_session.tscn")
	assert_eq(menu.play_button.get_theme_font("font"), menu.get_theme_font("font"))
	assert_eq(menu.get_node("Backdrop").process_mode, Node.PROCESS_MODE_DISABLED)


func test_credits_include_every_asset_from_the_credit_table() -> void:
	var source: String = FileAccess.get_file_as_string("res://docs/CREDITS.md")
	assert_false(source.is_empty())
	for line: String in source.split("\n"):
		if not line.begins_with("|") or line.begins_with("| Asset") or line.begins_with("|---"):
			continue
		var asset: String = line.split("|")[1].strip_edges()
		assert_true(MainMenu.CREDITS.contains(asset), "Missing credit: " + asset)
	menu.credits_button.pressed.emit()
	assert_eq((menu.get_node("Screens/Root/CreditsPanel/Box/Text") as Label).text, MainMenu.CREDITS)
	assert_true(menu.credits_panel.visible)
	assert_false(menu.menu.visible)


func test_cancel_returns_from_both_panels_and_back_button_works() -> void:
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	menu.settings_button.grab_focus()
	menu.settings_button.pressed.emit()
	menu._input(cancel)
	assert_eq(UI.top(), &"settings", "the menu leaves Back to the open screen")
	(UI._stack.back()["layer"].get_child(0) as SettingsScreen)._input(cancel)
	assert_eq(UI.top(), &"")
	assert_true(menu.settings_button.has_focus())
	menu.credits_button.pressed.emit()
	menu._input(cancel)
	assert_false(menu.credits_panel.visible)
	assert_true(menu.credits_button.has_focus())
	menu.credits_button.pressed.emit()
	(menu.get_node("Screens/Root/CreditsPanel/Box/Back") as Button).pressed.emit()
	assert_false(menu.credits_panel.visible)
	assert_true(menu.credits_button.has_focus())


func test_focus_neighbors_form_a_loop_and_panel_motion_has_no_overshoot() -> void:
	assert_eq(menu.play_button.get_node(menu.play_button.focus_neighbor_bottom), menu.host_button)
	assert_eq(menu.play_button.get_node(menu.play_button.focus_neighbor_top), menu.get_node("Screens/Root/Menu/Quit"))
	menu.credits_button.pressed.emit()
	menu._panel_tween.pause()
	assert_eq(menu.credits_panel.position.x, 12.0)
	assert_eq(menu.credits_panel.modulate.a, 0.0)
	menu._panel_tween.custom_step(0.06)
	assert_almost_eq(menu.credits_panel.position.x, 6.0, 0.01)
	assert_almost_eq(menu.credits_panel.modulate.a, 0.5, 0.01)
	menu._panel_tween.custom_step(0.06)
	assert_almost_eq(menu.credits_panel.position.x, 0.0, 0.01)
	assert_almost_eq(menu.credits_panel.modulate.a, 1.0, 0.01)


func test_solo_host_join_are_focusable_in_keyboard_and_gamepad_order() -> void:
	var buttons: Array[Button] = [
		menu.play_button,
		menu.host_button,
		menu.join_button,
		menu.character_button,
		menu.settings_button,
		menu.credits_button,
		menu.get_node("Screens/Root/Menu/Quit") as Button,
	]
	assert_eq(menu.play_button.text, "Play solo")
	assert_eq(menu.host_button.text, "Host and play")
	assert_eq(menu.join_button.text, "Join")
	for index: int in range(buttons.size()):
		var button: Button = buttons[index]
		var next: Button = buttons[(index + 1) % buttons.size()]
		var previous: Button = buttons[posmod(index - 1, buttons.size())]
		assert_eq(button.focus_mode, Control.FOCUS_ALL)
		assert_eq(button.get_node(button.focus_neighbor_bottom), next)
		assert_eq(button.get_node(button.focus_next), next)
		assert_eq(button.get_node(button.focus_neighbor_top), previous)
		assert_eq(button.get_node(button.focus_previous), previous)


func test_host_and_join_fields_have_default_focus_and_back_restores_button() -> void:
	menu.host_button.pressed.emit()
	assert_true(menu.host_panel.visible)
	assert_false(menu.menu.visible)
	assert_eq(menu.port_field.text, "7777")
	assert_true(menu.port_field.has_focus())
	(menu.get_node("Screens/Root/HostPanel/Box/Back") as Button).pressed.emit()
	assert_false(menu.host_panel.visible)
	assert_true(menu.host_button.has_focus())
	menu.join_button.pressed.emit()
	assert_true(menu.join_panel.visible)
	assert_true(menu.address_field.has_focus())
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	menu._input(cancel)
	assert_false(menu.join_panel.visible)
	assert_true(menu.join_button.has_focus())


func test_bad_join_shows_exact_error_without_calling_net_join() -> void:
	watch_signals(Net)
	menu.join_button.pressed.emit()
	menu.address_field.text = "https://not a server:banana"
	(menu.get_node("Screens/Root/JoinPanel/Box/Connect") as Button).pressed.emit()
	assert_true(menu.error_dialog.visible)
	assert_eq(
		menu.error_dialog.message_label.text, "That address doesn't look right. Use something like 192.168.1.20:7777."
	)
	assert_signal_not_emitted(Net, "join_started")
	assert_eq(Net.pending_join, "")
	assert_false(Net.is_online())
	assert_true(menu.error_dialog.action_button.has_focus())
	var root: Control = menu.get_node("Screens/Root") as Control
	assert_eq(root.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
	assert_eq(root.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED)
	menu.error_dialog.action_button.pressed.emit()
	assert_false(menu.error_dialog.visible)
	assert_true(menu.address_field.has_focus())
	assert_eq(root.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_INHERITED)
	assert_eq(root.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_INHERITED)


func test_menu_restores_saved_address_and_host_port_after_settings_reload() -> void:
	Settings.set_value(&"network", &"last_address", "192.168.1.20:24640")
	Settings.set_value(&"network", &"last_port", 24641)
	Settings._values = Settings.DEFAULTS.duplicate(true)
	Settings.load_settings()
	var reopened: MainMenu = MENU.instantiate() as MainMenu
	add_child_autofree(reopened)
	reopened.join_button.pressed.emit()
	assert_eq(reopened.address_field.text, "192.168.1.20:24640")
	reopened._close_coop()
	reopened.host_button.pressed.emit()
	assert_eq(reopened.port_field.text, "24641")


func test_address_validation_accepts_hosts_and_optional_port() -> void:
	assert_eq(MainMenu.normalized_address(" 192.168.1.20 "), "192.168.1.20:7777")
	assert_eq(MainMenu.normalized_address("192.168.1.20:24640"), "192.168.1.20:24640")
	assert_eq(MainMenu.normalized_address("localhost"), "localhost:7777")
	assert_eq(MainMenu.normalized_address("friends-server.lan:65535"), "friends-server.lan:65535")
	for invalid: String in [
		"",
		" ",
		"host:",
		"host:abc",
		"host:0",
		"host:65536",
		"1.2.3.999",
		"1.2.3",
		"host name",
		"http://host",
		"-host",
		"host-",
		"host..lan",
		"host:7777:8888",
	]:
		assert_eq(MainMenu.normalized_address(invalid), "", "Must reject: " + invalid)


func test_ipv6_addresses_normalize_for_the_existing_net_parser() -> void:
	var addresses: Dictionary[String, Array] = {
		"::1:24670": ["::1", 24670],
		"::1": ["::1", 7777],
		"[::1]": ["::1", 7777],
		"[::1]:24670": ["::1", 24670],
		"::": ["::", 7777],
		"2001:db8::a": ["2001:db8::a", 7777],
		"2001:db8::1:24670": ["2001:db8::1", 24670],
		"2001:db8::1:2467": ["2001:db8::1", 2467],
		"[2001:db8::1:2467]": ["2001:db8::1:2467", 7777],
		"[2001:db8::1:2467]:1234": ["2001:db8::1:2467", 1234],
		"::ffff:192.168.1.20": ["::ffff:192.168.1.20", 7777],
	}
	for address: String in addresses:
		var target: Array = addresses[address]
		var normalized: String = MainMenu.normalized_address(address)
		assert_eq(normalized, "%s:%d" % target, "Must accept: " + address)
		assert_eq(Net.parse_address(normalized), target, "Net must receive the intended host and port")
	var launch: Dictionary = MainMenu.parse_launch(PackedStringArray(["--join=::1:24670"]))
	assert_eq(Net.parse_address(MainMenu.normalized_address(launch["join"])), ["::1", 24670])


func test_ipv6_addresses_reject_bad_brackets_and_invalid_ports() -> void:
	for invalid: String in [
		"[::1",
		"::1]",
		"[]",
		"[localhost]",
		"[192.168.1.20]",
		"[::1]oops",
		"[[::1]]",
		"[::1]]:7777",
		"[::1]:",
		"[::1]:abc",
		"[::1]:0",
		"[::1]:65536",
		"[::1]:7777:8888",
		"::1:0",
		"::1:65536",
		"::g",
	]:
		assert_eq(MainMenu.normalized_address(invalid), "", "Must reject: " + invalid)


func test_bad_host_port_stays_in_menu_and_explains_valid_range() -> void:
	menu.host_button.pressed.emit()
	menu.port_field.text = "70000"
	(menu.get_node("Screens/Root/HostPanel/Box/Start") as Button).pressed.emit()
	assert_true(menu.error_dialog.visible)
	assert_eq(menu.error_dialog.message_label.text, "Use a port number from 1 to 65535.")
	assert_false(Net.is_online())
	assert_eq(Settings.get_value(&"network", &"last_port"), 7777)


func test_menu_and_coop_dialogs_fit_standard_ultrawide_and_tall_viewports() -> void:
	for dimensions: Vector2i in [Vector2i(1600, 900), Vector2i(2134, 900), Vector2i(1600, 1200)]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = dimensions
		viewport.disable_3d = true
		add_child_autofree(viewport)
		var resized_menu: MainMenu = MENU.instantiate() as MainMenu
		viewport.add_child(resized_menu)
		await wait_process_frames(2)
		var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(dimensions))
		for button: Control in resized_menu.menu.get_children():
			assert_true(bounds.encloses(button.get_global_rect()), "Menu at %s: %s" % [dimensions, button.name])
		assert_eq(viewport.gui_get_focus_owner(), resized_menu.play_button)
		resized_menu.host_button.pressed.emit()
		await wait_process_frames(2)
		assert_true(bounds.encloses(resized_menu.host_panel.get_global_rect()), "Host at %s" % dimensions)
		resized_menu._close_coop()
		resized_menu.join_button.pressed.emit()
		await wait_process_frames(2)
		assert_true(bounds.encloses(resized_menu.join_panel.get_global_rect()), "Join at %s" % dimensions)
		resized_menu._show_error(&"timeout", {"address": "192.168.1.20:7777"})
		await wait_process_frames(2)
		var panel: Control = resized_menu.error_dialog.get_node("Root/Center/Panel") as Control
		assert_true(bounds.encloses(panel.get_global_rect()), "Error at %s" % dimensions)
		viewport.free()


func test_command_line_join_and_host() -> void:
	assert_eq(MainMenu.parse_launch(PackedStringArray(["--join=10.0.0.5:24600"])), {"join": "10.0.0.5:24600"})
	assert_eq(MainMenu.parse_launch(PackedStringArray(["--host"])), {"host": Net.DEFAULT_PORT})
	assert_eq(MainMenu.parse_launch(PackedStringArray(["--verbose", "--host=24605"])), {"host": 24605})
	assert_eq(MainMenu.parse_launch(PackedStringArray(["--host=abc"])), {})
	assert_eq(MainMenu.parse_launch(PackedStringArray()), {})


func test_command_line_launch_runs_once_per_process() -> void:
	await wait_process_frames(2)
	assert_true(MainMenu.launch_consumed, "the first menu used up the launch arguments")
	menu._launch_from_command_line(PackedStringArray(["--host=24634"]))
	assert_false(Net.is_online(), "a later menu does not host or join again")

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


func test_enter_world_has_default_focus_and_existing_match_target() -> void:
	assert_true(menu.enter_button.has_focus())
	var match_screen: ScreenData = Content.get_item(&"screens", &"match") as ScreenData
	assert_true(ResourceLoader.exists(match_screen.scene))
	assert_eq(match_screen.scene, "res://systems/game/game_session.tscn")
	var row_font: FontVariation = menu.enter_button.get_theme_font("font") as FontVariation
	var body_font: FontVariation = menu.get_theme_font("font") as FontVariation
	assert_eq(row_font.base_font, body_font.base_font, "menu rows use Atkinson Hyperlegible, spaced out")
	assert_null(menu.get_node_or_null("Camera3D"), "no 3D map behind the menu any more")


## The separate launcher (F-82) replaced the launcher screen: a release build opens the main menu.
func test_no_launcher_screen_in_the_game() -> void:
	assert_false(Content.has(&"screens", &"launcher"))
	assert_false(ResourceLoader.exists("res://systems/launcher/launcher_screen.tscn"))
	assert_true(menu.menu.visible, "the main menu shows itself, nothing replaces it")


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
	assert_eq(menu.enter_button.get_node(menu.enter_button.focus_neighbor_bottom), menu.servers_button)
	assert_eq(menu.enter_button.get_node(menu.enter_button.focus_neighbor_top), menu.get_node("Screens/Root/Menu/Quit"))
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


func test_menu_rows_are_focusable_in_keyboard_and_gamepad_order() -> void:
	var buttons: Array[Button] = [
		menu.enter_button,
		menu.servers_button,
		menu.loadout_button,
		menu.research_button,
		menu.settings_button,
		menu.credits_button,
		menu.get_node("Screens/Root/Menu/Quit") as Button,
	]
	assert_eq(menu.enter_button.text, "PLAY")
	assert_eq(menu.servers_button.text, "SERVERS")
	assert_eq((buttons[-1] as Button).text, "QUIT")
	assert_null(menu.get_node_or_null("Screens/Root/Menu/Play"), "no Play solo: Enter world is the one way in")
	assert_null(menu.get_node_or_null("Screens/Root/HostPanel"), "no Host panel: your world is open by default")
	for index: int in range(buttons.size()):
		var button: Button = buttons[index]
		var next: Button = buttons[(index + 1) % buttons.size()]
		var previous: Button = buttons[posmod(index - 1, buttons.size())]
		assert_eq(button.focus_mode, Control.FOCUS_ALL)
		assert_eq(button.get_node(button.focus_neighbor_bottom), next)
		assert_eq(button.get_node(button.focus_next), next)
		assert_eq(button.get_node(button.focus_neighbor_top), previous)
		assert_eq(button.get_node(button.focus_previous), previous)


func test_servers_opens_the_server_browser_and_back_restores_the_button() -> void:
	menu.servers_button.grab_focus()
	menu.servers_button.pressed.emit()
	assert_eq(UI.top(), &"server_browser")
	assert_null(menu.get_node_or_null("Screens/Root/JoinPanel"), "joining goes through the browser")
	var browser: ServerBrowser = UI._stack.back()["layer"].get_child(0) as ServerBrowser
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	browser._unhandled_key_input(cancel)
	assert_eq(UI.top(), &"")
	assert_true(menu.servers_button.has_focus())


func test_menu_keeps_the_saved_port_after_settings_reload() -> void:
	Settings.set_value(&"network", &"last_port", 24641)
	Settings._values = Settings.DEFAULTS.duplicate(true)
	Settings.load_settings()
	assert_eq(Settings.get_value(&"network", &"last_port"), 24641)


func test_address_validation_accepts_hosts_and_optional_port() -> void:
	assert_eq(ServerAddress.normalized(" 192.168.1.20 "), "192.168.1.20:7777")
	assert_eq(ServerAddress.normalized("192.168.1.20:24640"), "192.168.1.20:24640")
	assert_eq(ServerAddress.normalized("localhost"), "localhost:7777")
	assert_eq(ServerAddress.normalized("friends-server.lan:65535"), "friends-server.lan:65535")
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
		assert_eq(ServerAddress.normalized(invalid), "", "Must reject: " + invalid)


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
		var normalized: String = ServerAddress.normalized(address)
		assert_eq(normalized, "%s:%d" % target, "Must accept: " + address)
		assert_eq(ServerAddress.parse(normalized), target, "Net must receive the intended host and port")
	var launch: Dictionary = MainMenu.parse_launch(PackedStringArray(["--join=::1:24670"]))
	assert_eq(ServerAddress.parse(ServerAddress.normalized(launch["join"])), ["::1", 24670])


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
		assert_eq(ServerAddress.normalized(invalid), "", "Must reject: " + invalid)


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
		assert_eq(viewport.gui_get_focus_owner(), resized_menu.enter_button)
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
	assert_eq(MainMenu.parse_launch(PackedStringArray(["--server", "--port=7778"])), {"server": true})


func test_command_line_launch_runs_once_per_process() -> void:
	await wait_process_frames(2)
	assert_true(MainMenu.launch_consumed, "the first menu used up the launch arguments")
	menu._launch_from_command_line(PackedStringArray(["--host=24634"]))
	assert_false(Net.is_online(), "a later menu does not host or join again")


## F-88 step 1: the FENLIGHT logo replaces the old wordmark and every row wears the brush look.
func test_logo_and_brush_rows() -> void:
	var logo: TextureRect = menu.get_node("Screens/Root/Logo") as TextureRect
	assert_eq(logo.texture.resource_path, "res://assets/ui/fenlight_logo.png")
	assert_null(menu.get_node_or_null("Screens/Root/Title"), "the EXPERIMENT / UNDEAD labels are gone")
	for button: Button in menu.menu.get_children().filter(func(node: Node) -> bool: return node is Button):
		assert_eq(button.theme_type_variation, &"MenuBrush", button.name)
		var focus: StyleBoxTexture = button.get_theme_stylebox("focus") as StyleBoxTexture
		assert_not_null(focus, button.name + " focus is the brush stroke")
		assert_eq(focus.texture.resource_path, "res://assets/ui/brush_stroke.png")
		assert_true(button.get_theme_stylebox("normal") is StyleBoxEmpty, button.name)
		assert_eq(button.text, button.text.to_upper(), button.name)


## F-88 step 2: the painted backdrop replaces the Halcyon Labs map. F-21: Research is a working row.
func test_painted_backdrop_and_research_row() -> void:
	assert_false(FileAccess.get_file_as_string("res://systems/ui/main_menu.tscn").contains("halcyon_labs/map.tscn"))
	assert_eq(menu.backdrop.texture.resource_path, "res://assets/ui/backdrops/main_menu.jpg")
	assert_gte(menu.backdrop.texture.get_width(), 1600)
	assert_false(menu.research_button.disabled)
	assert_eq(menu.research_button.focus_mode, Control.FOCUS_ALL)
	assert_eq(menu.research_button.tooltip_text, "")
	assert_eq(menu.research_button.text, "RESEARCH")
	var loadout: Button = menu.loadout_button
	var research: Button = menu.research_button
	assert_eq(loadout.get_node(loadout.focus_neighbor_bottom), research, "Loadout goes down to Research")
	assert_eq(research.get_node(research.focus_neighbor_bottom), menu.settings_button)
	assert_eq(menu.settings_button.get_node(menu.settings_button.focus_neighbor_top), research)


func test_backdrop_drifts_and_snow_falls_unless_reduce_motion() -> void:
	Settings.set_value(&"accessibility", &"reduce_motion", false)
	menu._process(5.0)
	assert_true(menu.snow.emitting)
	assert_true(menu.snow.visible)
	assert_ne(menu.backdrop.offset_left, 0.0, "the backdrop drifts")
	Settings.set_value(&"accessibility", &"reduce_motion", true)
	menu._process(5.0)
	assert_false(menu.snow.emitting)
	assert_false(menu.snow.visible, "flakes already falling are hidden too")
	assert_eq(menu.backdrop.offset_left, 0.0)
	assert_eq(menu.backdrop.offset_top, 0.0)


func test_hovering_a_row_moves_focus_so_only_one_brush_shows() -> void:
	menu.loadout_button.mouse_entered.emit()
	assert_true(menu.loadout_button.has_focus())
	assert_false(menu.enter_button.has_focus())

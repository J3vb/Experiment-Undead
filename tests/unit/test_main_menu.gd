## Front-end focus, shared settings, credits and the solo match destination.
extends GutTest

const MENU: PackedScene = preload("res://systems/ui/main_menu.tscn")

var menu: MainMenu


func before_each() -> void:
	menu = MENU.instantiate() as MainMenu
	add_child_autofree(menu)


func test_play_has_default_focus_and_existing_match_target() -> void:
	assert_true(menu.play_button.has_focus())
	assert_true(ResourceLoader.exists(MainMenu.PLAY_SCENE))
	assert_eq(MainMenu.PLAY_SCENE, "res://systems/game/game_session.tscn")
	assert_eq(menu.play_button.get_theme_font("font"), menu.get_theme_font("font"))
	assert_eq(menu.get_node("Backdrop").process_mode, Node.PROCESS_MODE_DISABLED)


func test_settings_uses_existing_scene_and_closed_restores_focus() -> void:
	menu.settings_button.pressed.emit()
	assert_eq(menu.settings_screen.scene_file_path, "res://systems/ui/settings_screen.tscn")
	assert_true(menu.settings_screen.is_visible_in_tree())
	assert_false(menu.menu.visible)
	menu._panel_tween.pause()
	assert_eq(menu.settings_screen.position.x, 12.0)
	assert_eq(menu.settings_screen.modulate.a, 0.0)
	menu._panel_tween.custom_step(0.12)
	assert_almost_eq(menu.settings_screen.position.x, 0.0, 0.01)
	assert_almost_eq(menu.settings_screen.modulate.a, 1.0, 0.01)
	menu.settings_screen.closed.emit()
	assert_false(menu.settings_screen.visible)
	assert_true(menu.settings_button.has_focus())


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
	menu.settings_button.pressed.emit()
	menu._input(cancel)
	assert_false(menu.settings_screen.visible)
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
	assert_eq(menu.play_button.get_node(menu.play_button.focus_neighbor_bottom), menu.character_button)
	assert_eq(menu.character_button.get_node(menu.character_button.focus_neighbor_bottom), menu.settings_button)
	assert_eq(menu.settings_button.get_node(menu.settings_button.focus_neighbor_top), menu.character_button)
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


func test_character_opens_solo_profile_and_close_restores_menu_focus() -> void:
	menu.character_button.pressed.emit()
	var screen: CharacterScreen = menu.character_screen
	assert_eq(screen.scene_file_path, MainMenu.CHARACTER_SCENE)
	assert_true(screen.is_visible_in_tree())
	assert_false(menu.menu.visible)
	assert_true(screen.is_ancestor_of(get_viewport().gui_get_focus_owner()))
	screen.closed.emit()
	assert_null(menu.character_screen)
	assert_true(menu.menu.visible)
	assert_true(menu.character_button.has_focus())
	assert_true(screen.is_queued_for_deletion())


func test_character_owns_cancel_and_only_one_screen_opens() -> void:
	menu.character_button.pressed.emit()
	var screen: CharacterScreen = menu.character_screen
	menu.character_button.pressed.emit()
	assert_eq(menu.character_screen, screen)
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	menu._input(cancel)
	assert_eq(menu.character_screen, screen, "Character screen receives its own back input")
	assert_false(menu.menu.visible)

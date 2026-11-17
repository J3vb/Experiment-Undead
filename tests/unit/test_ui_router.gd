## UI router: one stack, one scene change path and one mouse rule for every screen and panel.
extends GutTest

const TEST_SCREEN: String = "res://systems/ui/settings_screen.tscn"

var _root: ScreenData


func before_each() -> void:
	_root = UI._root
	UI._root = Content.get_item(&"screens", &"match") as ScreenData


func after_each() -> void:
	while UI.top() != &"":
		UI.pop()
	UI._root = _root


func _push_test_screen(layer: int = 20) -> Node:
	var data: ScreenData = ScreenData.new()
	data.scene = TEST_SCREEN
	data.layer = layer
	return UI._open(&"test_screen", data)


func test_mouse_rule_on_a_captures_mouse_root() -> void:
	assert_false(UI.mouse_should_be_free(), "match with nothing open captures the mouse")
	var panel: Node = Node.new()
	add_child(panel)
	UI.hold_mouse(panel, true)
	assert_true(UI.mouse_should_be_free(), "a holding panel frees the mouse")
	panel.free()
	assert_false(UI.mouse_should_be_free(), "a freed panel lets go")
	UI._root = Content.get_item(&"screens", &"main_menu") as ScreenData
	assert_true(UI.mouse_should_be_free(), "the main menu never captures")


func test_hold_and_release_by_the_same_node() -> void:
	var panel: Node = Node.new()
	add_child_autofree(panel)
	UI.hold_mouse(panel, true)
	UI.hold_mouse(panel, true)
	UI.hold_mouse(panel, false)
	assert_false(UI.mouse_should_be_free(), "one release undoes repeated holds")


func test_push_frees_the_mouse_and_closed_pops() -> void:
	var screen: Node = _push_test_screen()
	assert_eq(UI.top(), &"test_screen")
	assert_eq((screen.get_parent() as CanvasLayer).layer, 20)
	assert_true(UI.mouse_should_be_free())
	screen.emit_signal(&"closed")
	assert_eq(UI.top(), &"")
	assert_false(UI.mouse_should_be_free())


func test_push_settings_by_id_and_closed_returns_focus_to_the_opener() -> void:
	var button: Button = Button.new()
	add_child_autofree(button)
	button.grab_focus()
	var screen: Node = UI.push(&"settings")
	assert_eq(UI.top(), &"settings")
	assert_eq((screen.get_parent() as CanvasLayer).layer, 20)
	assert_false(button.has_focus(), "the screen takes focus")
	screen.emit_signal(&"closed")
	assert_eq(UI.top(), &"")
	assert_true(button.has_focus())


func test_push_above_an_overlay_keeps_the_higher_layer_and_hides_it() -> void:
	var lower: Node = _push_test_screen(30)
	var upper: Node = _push_test_screen(20)
	var lower_layer: CanvasLayer = lower.get_parent() as CanvasLayer
	assert_eq((upper.get_parent() as CanvasLayer).layer, 30)
	assert_false(lower_layer.visible)
	assert_eq(lower_layer.process_mode, Node.PROCESS_MODE_DISABLED)
	UI.pop()
	assert_true(lower_layer.visible)
	assert_eq(lower_layer.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_pop_gives_focus_back() -> void:
	var button: Button = Button.new()
	add_child_autofree(button)
	button.grab_focus()
	_push_test_screen()
	button.release_focus()
	UI.pop()
	assert_true(button.has_focus())


func test_pop_gives_focus_back_to_the_covered_screen() -> void:
	var lower: Node = _push_test_screen()
	var button: Button = Button.new()
	lower.add_child(button)
	button.grab_focus()
	_push_test_screen()
	UI.pop()
	assert_true(button.has_focus(), "focus saved before the lower screen was hidden")


func test_unknown_id_warns_and_returns_null() -> void:
	var before: int = Log.event_counts.get("ui.unknown_screen", 0)
	assert_null(UI.push(&"no_such_screen"))
	UI.replace(&"no_such_screen")
	assert_eq(Log.event_counts.get("ui.unknown_screen", 0), before + 2)
	assert_eq(UI.top(), &"")


func test_pop_on_empty_stack_warns() -> void:
	var before: int = Log.event_counts.get("ui.pop_empty", 0)
	UI.pop()
	assert_eq(Log.event_counts.get("ui.pop_empty", 0), before + 1)


func test_replace_clears_pushed_screens_and_unpauses() -> void:
	var runner_scene: Node = get_tree().current_scene
	var stand_in: Node = Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	_push_test_screen()
	get_tree().paused = true
	UI.replace(&"main_menu")
	assert_eq(UI.top(), &"")
	assert_false(get_tree().paused)
	await wait_process_frames(2)
	var menu: Node = get_tree().current_scene
	get_tree().current_scene = runner_scene
	assert_eq(menu.scene_file_path, "res://systems/ui/main_menu.tscn")
	assert_eq(UI._root, Content.get_item(&"screens", &"main_menu"), "the router knows the new root")
	menu.free()


func test_reload_empties_the_stack() -> void:
	var runner_scene: Node = get_tree().current_scene
	var stand_in: Node = (load("res://systems/ui/main_menu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	_push_test_screen()
	UI.reload()
	assert_eq(UI.top(), &"")
	await wait_process_frames(2)
	var reloaded: Node = get_tree().current_scene
	get_tree().current_scene = runner_scene
	assert_ne(reloaded, stand_in)
	reloaded.free()


## Gives the main menu a loading screen for one test; after_each order does not matter, it restores itself.
func _menu_with_loading() -> ScreenData:
	var menu: ScreenData = Content.get_item(&"screens", &"main_menu") as ScreenData
	menu.loading_screen = &"loading"
	menu.title = "Test Place"
	menu.tips = PackedStringArray(["Only tip"])
	return menu


func _restore_menu(menu: ScreenData) -> void:
	menu.loading_screen = &""
	menu.title = ""
	menu.tips = PackedStringArray()


func test_replace_with_a_loading_screen_shows_it_until_the_scene_is_in() -> void:
	var runner_scene: Node = get_tree().current_scene
	var stand_in: Node = Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	var menu_data: ScreenData = _menu_with_loading()
	UI.replace(&"main_menu")
	_restore_menu(menu_data)
	assert_true(UI.is_loading(), "the root loads on a thread")
	var layer: CanvasLayer = UI._loading_layer
	assert_not_null(layer, "a loading layer is up")
	assert_eq(layer.layer, 50, "loading sits on layer 50")
	var screen: LoadingScreen = layer.get_child(0) as LoadingScreen
	assert_eq(screen.title_label.text, "Test Place")
	assert_eq(screen.tip_label.text, "Only tip")
	var waited: int = 0
	while UI.is_loading() and waited < 600:
		await wait_process_frames(1)
		waited += 1
	assert_false(UI.is_loading(), "the load finished")
	await wait_process_frames(3)
	var menu: Node = get_tree().current_scene
	get_tree().current_scene = runner_scene
	assert_eq(menu.scene_file_path, "res://systems/ui/main_menu.tscn")
	assert_false(is_instance_valid(layer), "the loading layer is gone once the scene is in")
	menu.free()
	if is_instance_valid(stand_in):
		stand_in.free()


func test_replace_without_a_loading_screen_shows_none() -> void:
	var runner_scene: Node = get_tree().current_scene
	var stand_in: Node = Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	UI.replace(&"main_menu")
	assert_false(UI.is_loading())
	assert_null(UI._loading_layer)
	await wait_process_frames(2)
	var menu: Node = get_tree().current_scene
	get_tree().current_scene = runner_scene
	menu.free()


func test_a_failed_load_warns_and_falls_back_to_a_plain_change() -> void:
	var runner_scene: Node = get_tree().current_scene
	var stand_in: Node = Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	var before: int = Log.event_counts.get("ui.loading_failed", 0)
	UI._loading_path = "res://systems/ui/main_menu.tscn"
	UI._finish_loading("res://systems/ui/main_menu.tscn", null)
	assert_eq(Log.event_counts.get("ui.loading_failed", 0), before + 1)
	assert_false(UI.is_loading())
	await wait_process_frames(2)
	var menu: Node = get_tree().current_scene
	get_tree().current_scene = runner_scene
	assert_eq(menu.scene_file_path, "res://systems/ui/main_menu.tscn", "fell back to a plain scene change")
	menu.free()


func test_loading_screen_shows_progress_and_handles_no_tips() -> void:
	var screen: LoadingScreen = (load("res://systems/ui/loading_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(screen)
	screen.setup("Halcyon Labs", PackedStringArray())
	assert_eq(screen.tip_label.text, "", "no tips leaves the tip empty")
	screen.set_progress(0.4)
	assert_almost_eq(screen.progress_bar.value, 0.4, 0.001)
	screen.set_progress(3.0)
	assert_almost_eq(screen.progress_bar.value, 1.0, 0.001, "clamped to full")

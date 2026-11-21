## The front end loads the hub in the background so PLAY and joins skip a cold load.
extends GutTest

const MENU: PackedScene = preload("res://systems/ui/main_menu.tscn")


func test_menu_warms_the_hub_and_hands_it_to_ui_when_it_leaves() -> void:
	var menu: MainMenu = MENU.instantiate() as MainMenu
	add_child_autofree(menu)
	var hub: String = (Content.get_item(&"screens", &"hub") as ScreenData).scene
	menu.warm_hub()
	assert_ne(ResourceLoader.load_threaded_get_status(hub), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	remove_child(menu)
	var dropped: Array[String] = UI.get(&"_dropped_paths")
	assert_true(dropped.has(hub), "leaving must not wait for the load: that hung the game on quit")
	add_child(menu)
	await wait_until(
		func() -> bool:
			return ResourceLoader.load_threaded_get_status(hub) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
		30.0,
		"UI collected the warm-up once it was done"
	)
	assert_false(dropped.has(hub))


func test_a_menu_made_outside_the_front_end_does_not_warm_the_hub() -> void:
	var menu: MainMenu = MENU.instantiate() as MainMenu
	add_child_autofree(menu)
	assert_eq(menu.get(&"_hub_path"), "")

## The front end loads the hub in the background so PLAY and joins skip a cold load.
extends GutTest

const MENU: PackedScene = preload("res://systems/ui/main_menu.tscn")


func test_menu_warms_the_hub_and_collects_it_when_it_leaves() -> void:
	var menu: MainMenu = MENU.instantiate() as MainMenu
	add_child_autofree(menu)
	var hub: String = (Content.get_item(&"screens", &"hub") as ScreenData).scene
	menu.warm_hub()
	assert_ne(ResourceLoader.load_threaded_get_status(hub), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	remove_child(menu)
	assert_eq(ResourceLoader.load_threaded_get_status(hub), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	add_child(menu)


func test_a_menu_made_outside_the_front_end_does_not_warm_the_hub() -> void:
	var menu: MainMenu = MENU.instantiate() as MainMenu
	add_child_autofree(menu)
	assert_eq(menu.get(&"_hub_path"), "")

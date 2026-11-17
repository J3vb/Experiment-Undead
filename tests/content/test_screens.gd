## Every ScreenData points at a scene that instances; the roots are the main menu, the hub and the match.
extends GutTest


func _loading_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in Content.ids(&"screens"):
		var data: ScreenData = Content.get_item(&"screens", id) as ScreenData
		if data and not data.loading_screen.is_empty():
			ids.append(data.loading_screen)
	return ids


func test_every_screen_instances_and_uses_a_known_layer() -> void:
	var loading_ids: Array[StringName] = _loading_ids()
	for id: StringName in Content.ids(&"screens"):
		var data: ScreenData = Content.get_item(&"screens", id) as ScreenData
		assert_not_null(data, "%s is a ScreenData" % id)
		if data == null:
			continue
		assert_true(ResourceLoader.exists(data.scene), "%s scene exists" % id)
		assert_has([20, 30, 50], data.layer, "%s layer is 20, 30 or 50" % id)
		var scene: Node = (load(data.scene) as PackedScene).instantiate()
		assert_not_null(scene, "%s scene instances" % id)
		if scene and not data.root and not loading_ids.has(id):
			assert_true(scene.has_signal(&"closed"), "%s pushed screen emits closed" % id)
		if scene:
			scene.free()


func test_three_roots_and_only_the_places_capture_the_mouse() -> void:
	var roots: Array[StringName] = []
	for id: StringName in Content.ids(&"screens"):
		var data: ScreenData = Content.get_item(&"screens", id) as ScreenData
		if data.root:
			roots.append(id)
		assert_eq(data.captures_mouse, id in [&"match", &"hub"], "%s captures_mouse" % id)
	roots.sort()
	assert_eq(roots, [&"hub", &"main_menu", &"match"] as Array[StringName])
	assert_eq((Content.get_item(&"screens", &"main_menu") as ScreenData).scene, "res://systems/ui/main_menu.tscn")
	assert_eq((Content.get_item(&"screens", &"match") as ScreenData).scene, "res://systems/game/game_session.tscn")
	assert_eq((Content.get_item(&"screens", &"hub") as ScreenData).scene, "res://systems/game/hub_session.tscn")


func test_loading_screens_exist_and_their_roots_have_a_title_and_tips() -> void:
	for id: StringName in Content.ids(&"screens"):
		var data: ScreenData = Content.get_item(&"screens", id) as ScreenData
		if data.loading_screen.is_empty():
			continue
		assert_true(Content.has(&"screens", data.loading_screen), "%s loading screen exists" % id)
		var loading: ScreenData = Content.get_item(&"screens", data.loading_screen) as ScreenData
		if loading:
			assert_false(loading.root, "%s loading screen is not a root" % id)
			assert_eq(loading.layer, 50, "%s loading screen sits on the loading layer" % id)
		assert_false(data.title.is_empty(), "%s has a title" % id)
		assert_false(data.tips.is_empty(), "%s has tips" % id)
	assert_eq((Content.get_item(&"screens", &"match") as ScreenData).loading_screen, &"loading")


func test_the_hub_session_is_a_hub_and_the_match_is_not() -> void:
	var hub: GameSession = (load("res://systems/game/hub_session.tscn") as PackedScene).instantiate() as GameSession
	var match_session: GameSession = (
		(load("res://systems/game/game_session.tscn") as PackedScene).instantiate() as GameSession
	)
	assert_true(hub.is_hub)
	assert_false(match_session.is_hub)
	hub.free()
	match_session.free()

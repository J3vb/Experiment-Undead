## Every ScreenData points at a scene that instances; the two roots are the main menu and the match.
extends GutTest


func test_every_screen_instances_and_uses_a_known_layer() -> void:
	for id: StringName in Content.ids(&"screens"):
		var data: ScreenData = Content.get_item(&"screens", id) as ScreenData
		assert_not_null(data, "%s is a ScreenData" % id)
		if data == null:
			continue
		assert_true(ResourceLoader.exists(data.scene), "%s scene exists" % id)
		assert_has([20, 30], data.layer, "%s layer is 20 or 30" % id)
		var scene: Node = (load(data.scene) as PackedScene).instantiate()
		assert_not_null(scene, "%s scene instances" % id)
		if scene and not data.root:
			assert_true(scene.has_signal(&"closed"), "%s pushed screen emits closed" % id)
		if scene:
			scene.free()


func test_exactly_two_roots_and_only_the_match_captures_the_mouse() -> void:
	var roots: Array[StringName] = []
	for id: StringName in Content.ids(&"screens"):
		var data: ScreenData = Content.get_item(&"screens", id) as ScreenData
		if data.root:
			roots.append(id)
		assert_eq(data.captures_mouse, id == &"match", "%s captures_mouse" % id)
	roots.sort()
	assert_eq(roots, [&"main_menu", &"match"] as Array[StringName])
	assert_eq((Content.get_item(&"screens", &"main_menu") as ScreenData).scene, "res://systems/ui/main_menu.tscn")
	assert_eq((Content.get_item(&"screens", &"match") as ScreenData).scene, "res://systems/game/game_session.tscn")

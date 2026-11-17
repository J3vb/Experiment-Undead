## Halcyon Labs atmosphere (plan docs/plans/halcyon-labs-atmosphere.md): dead and
## flickering ceiling lights come from layout.json light_states and are saved into
## the blockout (dead ones have no light, so the editor bake sees them dark), and
## every light in atmosphere.tscn is a cheap cosmetic light: unshadowed, never baked, at most a few per room.
extends GutTest

const BLOCKOUT: String = "res://levels/halcyon_labs/blockout.tscn"
const ATMOSPHERE: String = "res://levels/halcyon_labs/atmosphere.tscn"
const BUILDER: String = "res://tools/blockout_builder.gd"
const DEAD_LIGHT: String = "res://levels/kit/ceiling_light_dead.tscn"
const MAX_LIGHTS_PER_ROOM: int = 3


func _states() -> Dictionary:
	return (load(BUILDER) as GDScript).load_layout("halcyon_labs").get("light_states", {})


func _light(root: Node, room: String, index: float) -> Node3D:
	return root.get_node("%s/Lights/Light%d" % [room, int(index)]) as Node3D


func test_light_states_are_saved_into_the_blockout() -> void:
	var states: Dictionary = _states()
	assert_gt(states.size(), 0, "layout.json has light_states")
	var saved: Node = (load(BLOCKOUT) as PackedScene).instantiate()
	for room: String in states:
		for index: float in states[room].get("flicker", []):
			var light: CeilingLight = _light(saved, room, index) as CeilingLight
			assert_true(light != null and light.flickers, "%s Light%d flickers" % [room, index])
		for index: float in states[room].get("dead", []):
			var dead: Node3D = _light(saved, room, index)
			assert_eq(dead.scene_file_path, DEAD_LIGHT, "%s Light%d is a dead fixture" % [room, index])
			assert_eq(dead.find_children("*", "Light3D", true, false).size(), 0, "so the bake gets nothing from it")
	saved.free()


func test_dead_fixtures_keep_working_lights_in_every_room() -> void:
	var saved: Node = (load(BLOCKOUT) as PackedScene).instantiate()
	for room: String in _states():
		var working: int = 0
		for node: Node in saved.get_node("%s/Lights" % room).get_children():
			if node is CeilingLight:
				working += 1
		assert_gt(working, 0, "%s still has light" % room)
	saved.free()


func test_atmosphere_lights_are_unshadowed_and_never_baked() -> void:
	var scene: Node = (load(ATMOSPHERE) as PackedScene).instantiate()
	var lights: Array[Node] = scene.find_children("*", "Light3D", true, false)
	assert_gt(lights.size(), 0, "atmosphere has lights")
	for node: Node in lights:
		var light: Light3D = node as Light3D
		assert_false(light.shadow_enabled, "%s unshadowed" % light.name)
		assert_eq(light.light_bake_mode, Light3D.BAKE_DISABLED, "%s not in the bake" % light.name)
		assert_true(light.distance_fade_enabled, "%s fades out with distance" % light.name)
	for node: Node in scene.find_children("*", "GeometryInstance3D", true, false):
		assert_ne((node as GeometryInstance3D).gi_mode, GeometryInstance3D.GI_MODE_STATIC, "%s not baked" % node.name)
	scene.free()


func test_atmosphere_keeps_a_few_lights_per_room() -> void:
	var scene: Node3D = (load(ATMOSPHERE) as PackedScene).instantiate() as Node3D
	add_child_autofree(scene)
	var rooms: Array = (load(BUILDER) as GDScript).load_layout("halcyon_labs")["rooms"]
	for room: Dictionary in rooms:
		var r: Array = room["rect"]
		var rect: Rect2 = Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).grow(0.5)
		var count: int = 0
		for node: Node in scene.find_children("*", "Light3D", true, false):
			var at: Vector3 = (node as Node3D).global_position
			if rect.has_point(Vector2(at.x, at.z)):
				count += 1
		assert_lte(count, MAX_LIGHTS_PER_ROOM, "%s atmosphere lights" % room["id"])


func test_alarm_beacons_spin_on_their_own() -> void:
	var scene: Node = (load(ATMOSPHERE) as PackedScene).instantiate()
	var players: Array[Node] = scene.find_children("*", "AnimationPlayer", true, false)
	assert_gt(players.size(), 0, "beacons have animation players")
	for node: Node in players:
		var player: AnimationPlayer = node as AnimationPlayer
		assert_ne(player.autoplay, &"", "%s autoplays" % player.get_parent().name)
		assert_eq(player.get_animation(player.autoplay).loop_mode, Animation.LOOP_LINEAR, "and loops")
	scene.free()

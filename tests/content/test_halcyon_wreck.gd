## Halcyon Labs wreck after the breakout (plan F-68 steps 3 to 5): kitchen fires are
## the Mess Hall's warm accent, every fire is a cheap cosmetic light, the truck fire
## goes with the wreckage in co-op, and red exit lamps glow without adding lights.
extends GutTest

const MAP: String = "res://levels/halcyon_labs/map.tscn"
const FIRE: String = "res://systems/effects/fire_spot.tscn"
const MESS_HALL: Rect2 = Rect2(38, 30, 20, 16)
const LABS: Rect2 = Rect2(36, 10, 16, 16)
const RESEARCH_SIGN: String = "res://assets/textures/signs/halcyon_research.png"

var _level: Node3D


func before_each() -> void:
	_level = (load(MAP) as PackedScene).instantiate() as Node3D
	add_child_autofree(_level)


func _fires() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node: Node in _level.find_children("*", "Node3D", true, false):
		if node.scene_file_path == FIRE:
			out.append(node as Node3D)
	return out


func test_kitchen_fires_burn_in_the_mess_hall() -> void:
	var in_mess: int = 0
	for fire: Node3D in _fires():
		var at: Vector3 = fire.global_position
		if MESS_HALL.has_point(Vector2(at.x, at.z)):
			in_mess += 1
	assert_eq(in_mess, 2, "two kitchen fires")


func test_fires_are_cheap_cosmetic_lights() -> void:
	assert_gt(_fires().size(), 0, "fires exist")
	for fire: Node3D in _fires():
		for node: Node in fire.find_children("*", "Light3D", true, false):
			var light: Light3D = node as Light3D
			assert_false(light.shadow_enabled, "%s casts no shadow" % fire.name)
			assert_eq(light.light_bake_mode, Light3D.BAKE_DISABLED, "%s is not baked" % fire.name)
			assert_true(light.distance_fade_enabled, "%s fades out" % fire.name)
			assert_almost_eq(light.distance_fade_begin, 20.0, 0.01, "%s fades from 20 m" % fire.name)
		for node: Node in fire.find_children("*", "GPUParticles3D", true, false):
			var particles: GPUParticles3D = node as GPUParticles3D
			assert_eq(particles.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s particles" % fire.name)
			assert_lte(particles.visibility_range_end, 30.0, "%s particles have a view range" % fire.name)


func test_truck_fire_goes_with_the_wreckage() -> void:
	var fire: Node = _level.get_node_or_null(^"TruckWreckage/Fire")
	assert_not_null(fire, "the wreck burns")
	if fire:
		assert_eq(fire.scene_file_path, FIRE, "with the shared fire spot")


func test_red_lamps_glow_without_lights() -> void:
	var lamps: Node = _level.get_node(^"Atmosphere/RedLamps")
	assert_gt(lamps.get_child_count(), 0, "exits have red lamps")
	assert_eq(lamps.find_children("*", "Light3D", true, false).size(), 0, "emission only, no extra lights")
	for node: Node in lamps.get_children():
		assert_eq((node as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_research_room_has_its_sign_and_one_mist_volume() -> void:
	var room: Node3D = _level.get_node(^"NavigationRegion3D/Blockout/labs/Props/labs_research_room") as Node3D
	assert_not_null(room, "the Labs research room stands in the map")
	if room == null:
		return
	var painted: Decal = _level.get_node(^"Signs/HalcyonResearch") as Decal
	assert_eq(painted.texture_albedo.resource_path, RESEARCH_SIGN, "HALCYON RESEARCH is painted on its back wall")
	assert_lt(
		Vector2(painted.global_position.x, painted.global_position.z).distance_to(
			Vector2(room.global_position.x, room.global_position.z)
		),
		1.5,
		"behind the glass"
	)
	var mist: int = 0
	for node: Node in _level.get_node(^"Atmosphere/Fog").get_children():
		var at: Vector3 = (node as Node3D).global_position
		if LABS.has_point(Vector2(at.x, at.z)):
			mist += 1
	assert_eq(mist, 1, "one mist volume in the Labs, inside the research room")

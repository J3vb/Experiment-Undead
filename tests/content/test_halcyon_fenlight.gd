## Fenlight growth in Halcyon Labs (plan F-68 step 2): vines and spill mounds are
## dressing, heaviest in Containment and the Labs and none at the Dock, and the
## Containment glow comes only from baked (Static) bio-green lights at the spills.
extends GutTest

const FENLIGHT: String = "res://levels/halcyon_labs/fenlight.tscn"
const MAP: String = "res://levels/halcyon_labs/map.tscn"
const BUILDER: String = "res://tools/blockout_builder.gd"
const LEAK: String = "res://assets/textures/story/leak_pool.png"
const GROWTH: Array[String] = ["vine_wall", "vine_wall_small", "vine_pillar", "vine_ceiling", "fenlight_spill"]
const BIO_GREEN: Color = Color("#8DFF3A")
const CONTAINMENT_FLOOR: float = -3.0


func _growth_per_room() -> Dictionary:
	var out: Dictionary = {}
	for item: Dictionary in (load(BUILDER) as GDScript).load_layout("halcyon_labs").get("dressing", []):
		if GROWTH.has(item["model"]):
			out[item["room"]] = int(out.get(item["room"], 0)) + 1
	return out


func _containment() -> Rect2:
	for room: Dictionary in (load(BUILDER) as GDScript).load_layout("halcyon_labs")["rooms"]:
		if room["id"] == "containment_wing":
			var r: Array = room["rect"]
			return Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
	return Rect2()


func test_growth_is_heaviest_in_containment_and_labs() -> void:
	var counts: Dictionary = _growth_per_room()
	var containment: int = counts.get("containment_wing", 0)
	var labs: int = counts.get("labs", 0)
	assert_gt(containment, 0, "Containment is overgrown")
	assert_gte(containment, labs, "Containment has the most growth")
	for room: String in counts:
		if room != "containment_wing" and room != "labs":
			assert_lt(counts[room], labs, "%s has less growth than the Labs" % room)
	assert_false(counts.has("loading_dock"), "no growth at the Dock, furthest from the tanks")


func test_glow_lights_are_baked_bio_green_and_unshadowed() -> void:
	var scene: Node3D = (load(FENLIGHT) as PackedScene).instantiate() as Node3D
	add_child_autofree(scene)
	var lights: Array[Node] = scene.find_children("*", "Light3D", true, false)
	assert_gte(lights.size(), 3, "a glow light at each Containment spill")
	for node: Node in lights:
		var light: Light3D = node as Light3D
		assert_eq(light.light_bake_mode, Light3D.BAKE_STATIC, "%s is baked (Static)" % light.name)
		assert_false(light.shadow_enabled, "%s casts no real-time shadow" % light.name)
		assert_true(light.light_color.is_equal_approx(BIO_GREEN), "%s is bio-green" % light.name)
		var at: Vector3 = light.global_position
		assert_true(_containment().has_point(Vector2(at.x, at.z)), "%s lights Containment only" % light.name)


func test_spill_pools_lie_on_the_containment_floor() -> void:
	var scene: Node3D = (load(FENLIGHT) as PackedScene).instantiate() as Node3D
	add_child_autofree(scene)
	var pools: Array[Node] = scene.find_children("*", "Decal", true, false)
	assert_gt(pools.size(), 0, "spill pools exist")
	for node: Node in pools:
		var pool: Decal = node as Decal
		assert_eq(pool.texture_albedo.resource_path, LEAK, "%s is a leak pool" % pool.name)
		assert_almost_eq(pool.global_position.y, CONTAINMENT_FLOOR, 0.1, "%s lies on the floor" % pool.name)
		assert_true(pool.distance_fade_enabled, "%s fades like story decals" % pool.name)


func test_map_loads_the_fenlight_scene() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	var fenlight: Node = map.get_node_or_null(^"Fenlight")
	assert_not_null(fenlight, "map instances fenlight.tscn")
	if fenlight:
		assert_eq(fenlight.scene_file_path, FENLIGHT)
	map.free()

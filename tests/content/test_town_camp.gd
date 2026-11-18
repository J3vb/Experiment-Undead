## Lantern Post camp props from tools/assets/town_camp.py (plan F-74 step 5, asset list P1-P13): one mesh each
## on the origin at the listed width, shared materials only, and the glowing parts really glow. Also checks that
## every town lamp bulb uses the emissive Bulb material (steps 3-4 used a paint that does not glow).
extends GutTest

const FOLDER: String = "res://assets/models/town/%s.glb"
const MATERIALS: String = "res://levels/materials/"
const BULB: String = "res://levels/materials/sodium_lamp.tres"
## Model id -> [width from the asset list, materials it must use].
const CAMP: Dictionary = {
	"fire_barrel": [0.64, ["iron.tres", "sodium_lamp.tres"]],
	"bench": [1.8, ["town_planks.tres", "town_dark_wood.tres"]],
	"supply_crate_large": [1.0, ["town_planks.tres", "town_snow.tres"]],
	"supply_crate_small": [0.6, ["town_planks.tres", "town_snow.tres"]],
	"ammo_case": [0.72, ["rust.tres", "iron.tres"]],
	"fenlight_crate": [0.9, ["specimen_tank.tres", "town_planks.tres"]],
	"lantern_hanging": [0.2, ["sodium_lamp.tres", "iron.tres"]],
	"lantern_table": [0.15, ["sodium_lamp.tres", "iron.tres"]],
	"string_lights": [9.2, ["sodium_lamp.tres", "iron.tres"]],
	"fence_rail": [3.0, ["town_dark_wood.tres", "town_snow.tres"]],
	"snow_drift_a": [2.4, ["town_snow.tres"]],
	"snow_drift_b": [1.4, ["town_snow.tres"]],
	"firewood_stack": [1.8, ["town_logs.tres", "town_snow.tres"]],
	"pine_tree": [4.4, ["pine.tres", "town_snow.tres"]],
}
## Models from earlier steps with a lamp bulb in them.
const LAMPS: Array[String] = ["stall_frame", "missions_board", "workbench", "floodlight"]
const SIZE_TOLERANCE: float = 0.2
## The pines are scattered over the whole ridge: lit by light probes, not baked into the lightmap.
const PROBE_LIT: Array[String] = ["pine_tree"]
const LIGHT_BAKING_STATIC: int = 2
const LIGHT_BAKING_DYNAMIC: int = 3


func _mesh(id: String) -> MeshInstance3D:
	var packed: PackedScene = load(FOLDER % id) as PackedScene
	assert_not_null(packed, id + " imports as a scene")
	var scene: Node = packed.instantiate()
	add_child_autofree(scene)
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 1, id + " is one mesh")
	return meshes[0] as MeshInstance3D


func _material_paths(id: String) -> Array[String]:
	var mesh: Mesh = _mesh(id).mesh
	var paths: Array[String] = []
	for i: int in mesh.get_surface_count():
		paths.append(mesh.surface_get_material(i).resource_path)
	return paths


func test_camp_props_import_with_shared_materials() -> void:
	for id: String in CAMP:
		var settings: ConfigFile = ConfigFile.new()
		assert_eq(settings.load(FOLDER % id + ".import"), OK)
		var baking: int = LIGHT_BAKING_DYNAMIC if id in PROBE_LIT else LIGHT_BAKING_STATIC
		assert_eq(settings.get_value("params", "meshes/light_baking"), baking, id + " light baking")
		assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/prop_import.gd", id)
		var used: Array[String] = _material_paths(id)
		for material: String in used:
			assert_true(material.begins_with(MATERIALS), "%s uses a shared material: %s" % [id, material])
		for material: String in CAMP[id][1]:
			assert_has(used, MATERIALS + material, "%s uses %s" % [id, material])


func test_camp_props_stand_on_the_origin_at_their_listed_width() -> void:
	for id: String in CAMP:
		var box: AABB = _mesh(id).get_aabb()
		assert_almost_eq(box.position.y, 0.0, 0.01, id + " bottom on the ground")
		assert_lt(Vector2(box.get_center().x, box.get_center().z).length(), 0.05, id + " origin under the middle")
		var ratio: float = box.size.x / float(CAMP[id][0])
		assert_between(ratio, 1.0 - SIZE_TOLERANCE, 1.0 + SIZE_TOLERANCE, id + " width")


func test_every_town_lamp_bulb_glows() -> void:
	var bulb: StandardMaterial3D = load(BULB) as StandardMaterial3D
	assert_true(bulb.emission_enabled, "the Bulb material emits light")
	for id: String in LAMPS:
		assert_has(_material_paths(id), BULB, id + " lamp uses the glowing Bulb material")

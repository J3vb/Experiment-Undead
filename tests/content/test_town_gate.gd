## Lantern Post Deploy gate from tools/assets/town_gate.py (plan F-74 step 4, asset list G1-G5): one static
## lightmapped mesh each on the origin, the listed size, shared materials only, and the slots that make the
## concept look (green tunnel strips, hazard stripes, the Banner cloth, red beacons, lamp glow).
extends GutTest

const MODELS: String = "res://assets/models/%s.glb"
const MATERIALS: String = "res://levels/materials/"
## Model path -> [size from the asset list (width, height, depth), materials it must use].
const GATE: Dictionary = {
	"town_large/gate_wall": [Vector3(8, 8, 3), ["raw_concrete.tres", "iron.tres", "town_snow.tres"]],
	"town_large/gate_tunnel":
	[Vector3(10, 9, 14), ["raw_concrete.tres", "town_hazard.tres", "specimen_tank.tres", "iron.tres"]],
	"town/banner": [Vector3(1.4, 4.5, 0.2), ["town_banner.tres", "iron.tres"]],
	"town/floodlight": [Vector3(0.8, 2.1, 0.5), ["sodium_paint.tres", "iron.tres"]],
	"town_large/radio_mast": [Vector3(3, 30, 3), ["beacon_red.tres", "iron.tres", "raw_concrete.tres"]],
}
const SIZE_TOLERANCE: float = 0.2
const BANNER_SHADER_PATTERN: int = 8


func _mesh(path: String) -> MeshInstance3D:
	var packed: PackedScene = load(MODELS % path) as PackedScene
	assert_not_null(packed, path + " imports as a scene")
	var scene: Node = packed.instantiate()
	add_child_autofree(scene)
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 1, path + " is one mesh")
	return meshes[0] as MeshInstance3D


func _material_paths(path: String) -> Array[String]:
	var mesh: Mesh = _mesh(path).mesh
	var paths: Array[String] = []
	for i: int in mesh.get_surface_count():
		paths.append(mesh.surface_get_material(i).resource_path)
	return paths


func test_gate_models_are_static_lightmapped_with_shared_materials() -> void:
	for path: String in GATE:
		var settings: ConfigFile = ConfigFile.new()
		assert_eq(settings.load(MODELS % path + ".import"), OK)
		assert_eq(settings.get_value("params", "meshes/light_baking"), 2, path + " bakes into the lightmap")
		assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/prop_import.gd", path)
		for material: String in _material_paths(path):
			assert_true(material.begins_with(MATERIALS), "%s uses a shared material: %s" % [path, material])


func test_gate_models_stand_on_the_origin_at_their_listed_size() -> void:
	for path: String in GATE:
		var box: AABB = _mesh(path).get_aabb()
		var listed: Vector3 = GATE[path][0]
		assert_almost_eq(box.position.y, 0.0, 0.01, path + " bottom on the ground")
		assert_lt(Vector2(box.get_center().x, box.get_center().z).length(), 0.05, path + " origin under the middle")
		for axis: int in 3:
			var ratio: float = box.size[axis] / listed[axis]
			assert_between(ratio, 1.0 - SIZE_TOLERANCE, 1.0 + SIZE_TOLERANCE, "%s axis %d size" % [path, axis])


func test_gate_models_use_their_concept_materials() -> void:
	for path: String in GATE:
		var used: Array[String] = _material_paths(path)
		for material: String in GATE[path][1]:
			assert_has(used, MATERIALS + material, "%s uses %s" % [path, material])


func test_banner_material_draws_the_emblem() -> void:
	var banner: ShaderMaterial = load(MATERIALS + "town_banner.tres") as ShaderMaterial
	assert_not_null(banner, "Banner slot material loads")
	assert_eq(banner.get_shader_parameter("pattern"), BANNER_SHADER_PATTERN, "banner cloth pattern")
	var centre: Vector2 = banner.get_shader_parameter("emblem_center")
	var cloth: AABB = _mesh("town/banner").get_aabb()
	assert_between(centre.y, cloth.size.y * 0.4, cloth.size.y * 0.8, "emblem sits in the upper half of the cloth")

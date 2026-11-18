## Lantern Post buildings from tools/assets/town_buildings.py (plan F-74, asset list B1-B6): one static
## lightmapped mesh each, standing on the origin, sized like the asset list, front facing +Z, and every
## surface swapped for a shared town material.
extends GutTest

const FOLDER: String = "res://assets/models/town_large/%s.glb"
const MATERIALS: String = "res://levels/materials/"
## Model id -> [size from the asset list (width, height, depth), material that sits on the front, has glow].
const BUILDINGS: Dictionary = {
	"lodge_lantern_post": [Vector3(12, 11, 9), "town_planks.tres", true],
	"lodge_common_room": [Vector3(14, 10, 9), "town_dark_wood.tres", true],
	"cabin_small": [Vector3(7, 6, 6), "town_planks.tres", true],
	"cabin_two_storey": [Vector3(7, 9, 7), "town_planks.tres", true],
	"shed_lean_to": [Vector3(4, 3, 3), "town_dark_wood.tres", false],
	"watchtower": [Vector3(4, 13, 4), "lit_window.tres", true],
}
const SIZE_TOLERANCE: float = 0.2


func _mesh(id: String) -> MeshInstance3D:
	var packed: PackedScene = load(FOLDER % id) as PackedScene
	assert_not_null(packed, id + " imports as a scene")
	var scene: Node = packed.instantiate()
	add_child_autofree(scene)
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 1, id + " is one mesh")
	return meshes[0] as MeshInstance3D


func test_every_building_is_static_lightmapped_with_shared_materials() -> void:
	for id: String in BUILDINGS:
		var settings: ConfigFile = ConfigFile.new()
		assert_eq(settings.load(FOLDER % id + ".import"), OK)
		assert_eq(settings.get_value("params", "meshes/light_baking"), 2, id + " bakes into the lightmap")
		assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/prop_import.gd", id)
		var mesh: Mesh = _mesh(id).mesh
		for i: int in mesh.get_surface_count():
			var path: String = mesh.surface_get_material(i).resource_path
			assert_true(path.begins_with(MATERIALS), "%s surface %d uses a shared town material: %s" % [id, i, path])


func test_buildings_stand_on_the_origin_at_their_listed_size() -> void:
	for id: String in BUILDINGS:
		var box: AABB = _mesh(id).get_aabb()
		var listed: Vector3 = BUILDINGS[id][0]
		assert_almost_eq(box.position.y, 0.0, 0.01, id + " bottom on the ground")
		assert_lt(Vector2(box.get_center().x, box.get_center().z).length(), 0.05, id + " origin under the middle")
		for axis: int in 3:
			var ratio: float = box.size[axis] / listed[axis]
			assert_between(ratio, 1.0 - SIZE_TOLERANCE, 1.0 + SIZE_TOLERANCE, "%s axis %d size" % [id, axis])


func test_fronts_face_plus_z() -> void:
	for id: String in BUILDINGS:
		var mesh: Mesh = _mesh(id).mesh
		var front_z: float = 0.0
		var count: int = 0
		for i: int in mesh.get_surface_count():
			if mesh.surface_get_material(i).resource_path != MATERIALS + BUILDINGS[id][1]:
				continue
			for vertex: Vector3 in mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
				front_z += vertex.z
				count += 1
		assert_gt(count, 0, id + " has its front material")
		assert_gt(front_z / maxf(count, 1), 0.3, id + " porch, balcony or lamp is on the +Z (front) side")


func test_windows_glow() -> void:
	for id: String in BUILDINGS:
		if not BUILDINGS[id][2]:
			continue
		var mesh: Mesh = _mesh(id).mesh
		var glowing: bool = false
		for i: int in mesh.get_surface_count():
			var material: BaseMaterial3D = mesh.surface_get_material(i) as BaseMaterial3D
			glowing = glowing or (material != null and material.emission_enabled)
		assert_true(glowing, id + " has lit windows")

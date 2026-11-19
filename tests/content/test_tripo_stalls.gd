## The three Lantern Post stalls made in Tripo (tools/assets/tripo_intake.py, kind "large"): one static
## lightmapped mesh on the origin, as wide as the stall frame they replace, with their own baked maps.
extends GutTest

const FOLDER: String = "res://assets/models/town_large/%s.glb"
const STALLS: Array[String] = ["stall_technician", "stall_gunsmith", "stall_trader"]
const FRAME_WIDTH: float = 4.2


func _mesh(id: String) -> MeshInstance3D:
	var packed: PackedScene = load(FOLDER % id) as PackedScene
	assert_not_null(packed, id + " imports as a scene")
	var scene: Node = packed.instantiate()
	add_child_autofree(scene)
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 1, id + " is one mesh")
	return meshes[0] as MeshInstance3D


func test_stalls_bake_into_the_lightmap() -> void:
	for id: String in STALLS:
		var settings: ConfigFile = ConfigFile.new()
		assert_eq(settings.load(FOLDER % id + ".import"), OK)
		assert_eq(settings.get_value("params", "meshes/light_baking"), 2, id + " bakes into the lightmap")


func test_stalls_stand_on_the_origin_as_wide_as_the_frame() -> void:
	for id: String in STALLS:
		var box: AABB = _mesh(id).get_aabb()
		assert_almost_eq(box.position.y, 0.0, 0.01, id + " bottom on the ground")
		assert_lt(Vector2(box.get_center().x, box.get_center().z).length(), 0.05, id + " origin under the middle")
		assert_almost_eq(box.size.x, FRAME_WIDTH, 0.1, id + " width")


func test_stalls_keep_their_baked_maps() -> void:
	for id: String in STALLS:
		var mesh: Mesh = _mesh(id).mesh
		assert_eq(mesh.get_surface_count(), 1, id + " has one material")
		var material: StandardMaterial3D = mesh.surface_get_material(0) as StandardMaterial3D
		assert_not_null(material, id + " material")
		assert_not_null(material.albedo_texture, id + " albedo map")
		assert_not_null(material.normal_texture, id + " normal map")

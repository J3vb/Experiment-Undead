## Prop library family 1 from tools/assets/library_barriers.py (plan F-77 step 2): each model is one mesh
## standing on its origin at the catalogue size, with the shared materials it was built for. Sandbags use the
## clean Burlap slot (no snow), and the boom barrier's tip lamp is the glowing red Beacon.
extends GutTest

const MATERIALS: String = "res://levels/materials/"
const SIZE_TOLERANCE: float = 0.1
## Model path -> [catalogue size W x D x H in metres, materials it must use].
const BARRIERS: Dictionary = {
	"props/jersey_barrier": [Vector3(2.0, 0.8, 0.6), ["raw_concrete.tres", "town_hazard.tres", "rubber.tres"]],
	"props/concrete_block": [Vector3(1.7, 0.9, 0.8), ["raw_concrete.tres", "iron.tres", "rust.tres"]],
	"props/sandbag_wall": [Vector3(2.1, 0.9, 0.5), ["burlap.tres"]],
	"props/sandbag_corner": [Vector3(1.5, 0.9, 1.5), ["burlap.tres"]],
	"props/boom_barrier": [Vector3(4.6, 1.1, 0.6), ["panel_paint.tres", "town_hazard.tres", "beacon_red.tres"]],
	"props/chain_link_fence": [Vector3(3.1, 2.0, 0.1), ["steel.tres"]],
	"props/chain_link_gate": [Vector3(2.3, 2.1, 0.1), ["steel.tres", "rubber.tres"]],
	"props/razor_wire_fence": [Vector3(3.1, 2.3, 0.5), ["steel.tres"]],
	"props/hard_case": [Vector3(0.9, 0.4, 0.6), ["town_hazard.tres", "rubber.tres"]],
	"dressing/jerrycan_pair": [Vector3(0.8, 0.5, 0.3), ["panel_paint.tres", "rubber.tres"]],
	"props/pallet_stack": [Vector3(1.3, 0.6, 0.9), ["wood.tres"]],
}


func _mesh(id: String) -> MeshInstance3D:
	var packed: PackedScene = load("res://assets/models/%s.glb" % id) as PackedScene
	assert_not_null(packed, id + " imports as a scene")
	var scene: Node = packed.instantiate()
	add_child_autofree(scene)
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 1, id + " is one mesh")
	return meshes[0] as MeshInstance3D


func test_barriers_use_their_shared_materials() -> void:
	for id: String in BARRIERS:
		var mesh: Mesh = _mesh(id).mesh
		var used: Array[String] = []
		for i: int in mesh.get_surface_count():
			used.append(mesh.surface_get_material(i).resource_path)
		for material: String in BARRIERS[id][1]:
			assert_has(used, MATERIALS + material, "%s uses %s" % [id, material])


func test_barriers_stand_on_the_origin_at_catalogue_size() -> void:
	for id: String in BARRIERS:
		var box: AABB = _mesh(id).get_aabb()
		var size: Vector3 = BARRIERS[id][0]
		assert_almost_eq(box.position.y, 0.0, 0.01, id + " bottom on the ground")
		assert_lt(Vector2(box.get_center().x, box.get_center().z).length(), 0.05, id + " origin under the middle")
		for axis: int in 3:
			assert_almost_eq(box.size[axis], size[axis], SIZE_TOLERANCE, "%s size on axis %d" % [id, axis])


func test_sandbags_stay_clean_and_the_boom_lamp_glows() -> void:
	var burlap: ShaderMaterial = load(MATERIALS + "burlap.tres") as ShaderMaterial
	assert_eq(burlap.get_shader_parameter("snow_on_top"), 0.0, "library props carry no snow")
	var beacon: StandardMaterial3D = load(MATERIALS + "beacon_red.tres") as StandardMaterial3D
	assert_true(beacon.emission_enabled, "the boom tip lamp glows")

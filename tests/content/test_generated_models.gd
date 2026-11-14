## Checks the models built by tools/assets/build_models.py: they import,
## have the right size and axes, and keep the parts code needs by name.
extends GutTest

const RIFLE: String = "res://assets/models/weapons/rifle_ar.glb"
const SHOTGUN: String = "res://assets/models/weapons/shotgun_brenner.glb"
const WALL: String = "res://assets/models/kit/wall_panel.glb"
const ZOMBIES: String = "res://assets/models/zombies/%s.glb"
const ZOMBIE_PARTS: Array[String] = ["Hips", "Torso", "Head", "EyeL", "EyeR", "ArmL", "ArmR"]


func _bounds(node: Node, xform: Transform3D, out: Array[AABB]) -> void:
	var here: Transform3D = xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var box: AABB = here * (node as MeshInstance3D).get_aabb()
		out[0] = box if out[0].size == Vector3.ZERO else out[0].merge(box)
	for child: Node in node.get_children():
		_bounds(child, here, out)


func _size_of(scene: Node) -> AABB:
	var out: Array[AABB] = [AABB()]
	_bounds(scene, Transform3D.IDENTITY, out)
	return out[0]


func _load(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, path + " imports as a scene")
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func test_rifle_has_moving_parts_and_muzzle() -> void:
	var gun: Node3D = _load(RIFLE)
	if gun == null:
		return
	for part: String in ["Magazine", "Bolt", "Muzzle", "Barrel", "OpticGlass"]:
		assert_not_null(gun.find_child(part, true, false), "rifle has " + part)
	var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
	if muzzle:
		assert_lt(muzzle.position.z, -0.5, "muzzle points forward (-Z)")
	var box: AABB = _size_of(gun)
	assert_almost_eq(box.size.z, 1.02, 0.03, "rifle is about 1 m long")
	assert_lt(box.size.x, 0.1, "rifle is narrow")
	gun.free()


func test_rifle_body_is_one_mesh() -> void:
	var gun: Node3D = _load(RIFLE)
	if gun == null:
		return
	var receiver: Node = gun.find_child("Receiver", true, false)
	assert_true(receiver is MeshInstance3D, "static rifle parts are joined into Receiver")
	var meshes: Array[Node] = gun.find_children("*", "MeshInstance3D", true, false)
	assert_lt(meshes.size(), 10, "few draw calls: only moving parts are separate meshes")
	gun.free()


func test_shotgun_has_a_pump_and_muzzle() -> void:
	var gun: Node3D = _load(SHOTGUN)
	if gun == null:
		return
	assert_true(gun.find_child("Receiver", true, false) is MeshInstance3D, "static parts are joined into Receiver")
	assert_true(gun.find_child("Bolt", true, false) is MeshInstance3D, "the pump is the Bolt node, so it racks")
	assert_null(gun.find_child("Magazine", true, false), "tube-fed: no magazine to drop")
	var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
	assert_not_null(muzzle, "shotgun has a Muzzle")
	if muzzle:
		assert_lt(muzzle.position.z, -0.5, "muzzle points forward (-Z)")
	var box: AABB = _size_of(gun)
	assert_almost_eq(box.size.z, 1.0, 0.05, "shotgun is about 1 m long")
	assert_lt(box.size.x, 0.1, "shotgun is narrow")
	assert_lt(gun.find_children("*", "MeshInstance3D", true, false).size(), 4, "few draw calls")
	gun.free()


func test_kestrel_has_moving_parts_and_iron_sights() -> void:
	var gun: Node3D = _load("res://assets/models/weapons/kestrel_smg.glb")
	if gun == null:
		return
	for part: String in ["Magazine", "Bolt", "Muzzle"]:
		assert_not_null(gun.find_child(part, true, false), "Kestrel has " + part)
	assert_true(gun.find_child("Receiver", true, false) is MeshInstance3D)
	var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
	if muzzle:
		assert_lt(muzzle.position.z, -0.35, "muzzle points forward (-Z)")
	var box: AABB = _size_of(gun)
	assert_between(box.size.z, 0.65, 0.75, "compact SMG with stock extended")
	assert_lt(box.size.x, 0.1, "narrow SMG")
	assert_lt(gun.find_children("*", "MeshInstance3D", true, false).size(), 6, "few draw calls")
	gun.free()


func test_wall_panel_fits_the_kit_grid() -> void:
	var wall: Node3D = _load(WALL)
	if wall == null:
		return
	var box: AABB = _size_of(wall)
	assert_almost_eq(box.size.x, 2.0, 0.01, "wall is 2 m wide")
	assert_almost_eq(box.size.y, 3.0, 0.01, "wall is 3 m high")
	assert_almost_eq(box.position.y, 0.0, 0.01, "origin at the floor")
	assert_lt(box.size.z, 0.3, "wall is thin")
	wall.free()


func _material(mesh_node: MeshInstance3D) -> BaseMaterial3D:
	return mesh_node.mesh.surface_get_material(0) as BaseMaterial3D


func _check_zombie(id: String) -> Node3D:
	var zombie: Node3D = _load(ZOMBIES % id)
	if zombie == null:
		return null
	for part: String in ZOMBIE_PARTS:
		assert_not_null(zombie.find_child(part, true, false), id + " has " + part)
	var eye: Node3D = zombie.find_child("EyeL", true, false) as Node3D
	if eye:
		assert_gt(eye.position.z, 0.0, id + " faces +Z (eyes on the front of the head)")
	var head: MeshInstance3D = zombie.find_child("Head", true, false) as MeshInstance3D
	if head:
		var head_value: float = _material(head).albedo_color.get_luminance()
		for node: Node in zombie.find_children("*", "MeshInstance3D", true, false):
			var mat: BaseMaterial3D = _material(node as MeshInstance3D)
			if node != head and not mat.emission_enabled:
				assert_gt(head_value, mat.albedo_color.get_luminance(), id + " head is lighter than " + node.name)
	return zombie


func test_shambler_is_upright_and_reaching() -> void:
	var zombie: Node3D = _check_zombie("shambler")
	if zombie == null:
		return
	var box: AABB = _size_of(zombie)
	assert_between(box.size.y, 1.7, 1.95, "shambler is about player height")
	assert_almost_eq(box.position.y, 0.0, 0.02, "feet on the floor")
	assert_gt(box.end.z, 0.5, "arms reach forward")
	assert_not_null(zombie.find_child("CoatSkirt", true, false), "shambler wears a lab coat")
	zombie.free()


func test_crawler_is_flat_to_the_ground() -> void:
	var zombie: Node3D = _check_zombie("crawler")
	if zombie == null:
		return
	var box: AABB = _size_of(zombie)
	assert_lt(box.size.y, 0.8, "crawler is low")
	assert_gt(box.size.z, 1.2, "crawler is long")
	assert_null(zombie.find_child("LegL", true, false), "crawler has no legs")
	zombie.free()


func test_bloater_is_wide_with_a_glowing_belly() -> void:
	var zombie: Node3D = _check_zombie("bloater")
	if zombie == null:
		return
	var box: AABB = _size_of(zombie)
	assert_gt(box.size.x, 1.1, "bloater is wide")
	var belly: MeshInstance3D = zombie.find_child("Belly", true, false) as MeshInstance3D
	assert_not_null(belly, "bloater has a Belly code can pulse")
	if belly:
		assert_true(_material(belly).emission_enabled, "belly glows")
	zombie.free()

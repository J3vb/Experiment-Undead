## Checks the models built by tools/assets/build_models.py: they import,
## have the right size and axes, and keep the parts code needs by name.
extends GutTest

const RIFLE: String = "res://assets/models/weapons/rifle_ar.glb"
const SHOTGUN: String = "res://assets/models/weapons/shotgun_brenner.glb"
const KESTREL: String = "res://assets/models/weapons/kestrel_smg.glb"
const TALON: String = "res://assets/models/weapons/talon_dmr.glb"
const WALL: String = "res://assets/models/kit/wall_panel.glb"
const ZOMBIES: String = "res://assets/models/zombies/%s.glb"
const ZOMBIE_PARTS: Array[String] = ["Hips", "Torso", "Head", "EyeL", "EyeR", "ArmL", "ArmR"]
## The viewmodels place their ScopeLens disc at this Z (towards the player); scope geometry must stay in front.
const SCOPE_LENS_Z: float = 0.128
const SCOPE_BOTTOM: float = 0.074
const SCOPE_HALF_WIDTH: float = 0.03


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
	var gun: Node3D = _load(KESTREL)
	if gun == null:
		return
	for part: String in ["Magazine", "Bolt", "Muzzle", "Barrel", "FoldingStock", "IronSights", "Grip", "Trigger"]:
		assert_not_null(gun.find_child(part, true, false), "Kestrel has " + part)
	assert_true(gun.find_child("Receiver", true, false) is MeshInstance3D)
	var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
	if muzzle:
		assert_lt(muzzle.position.z, -0.35, "muzzle points forward (-Z)")
	var box: AABB = _size_of(gun)
	assert_between(box.size.z, 0.65, 0.75, "compact SMG with stock extended")
	assert_lt(box.size.x, 0.1, "narrow SMG")
	assert_lte(gun.find_children("*", "MeshInstance3D", true, false).size(), 10, "bounded separate parts")
	var stock: Node3D = gun.find_child("FoldingStock", true, false) as Node3D
	assert_not_null(stock, "folding stock has its own hinge pivot")
	if stock:
		assert_between(stock.position.z, 0.1, 0.2, "stock pivot sits at the receiver hinge")
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


func test_talon_has_rifle_parts_and_a_long_barrel() -> void:
	var gun: Node3D = _load(TALON)
	if gun == null:
		return
	for part: String in [
		"Magazine", "Bolt", "Muzzle", "Barrel", "MuzzleBrake", "OpticGlass", "Optic", "Bipod", "Stock"
	]:
		assert_not_null(gun.find_child(part, true, false), "Talon has " + part)
	assert_true(gun.find_child("Receiver", true, false) is MeshInstance3D, "static body joined")
	var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
	assert_lt(muzzle.position.z, -0.8, "long barrel points forward")
	assert_almost_eq(_size_of(gun).size.z, 1.3, 0.05, "longer than the AR")
	assert_lte(gun.find_children("*", "MeshInstance3D", true, false).size(), 14, "bounded separate parts")
	assert_not_null(gun.find_child("ScopeLensMount", true, false), "rear lens has an explicit mount")
	gun.free()


func _triangle_count(model: Node3D) -> int:
	var count: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		count += int((node as MeshInstance3D).mesh.get_faces().size() / 3.0)
	return count


func test_rebuilt_guns_keep_rifle_triangle_budget_and_distinct_materials() -> void:
	var rifle: Node3D = _load(RIFLE)
	var budget: int = int(_triangle_count(rifle) * 1.5)
	rifle.free()
	for path: String in [KESTREL, TALON]:
		var gun: Node3D = _load(path)
		var triangles: int = _triangle_count(gun)
		assert_gt(triangles, 0, path + " has geometry")
		assert_lte(triangles, budget, path + " stays below 1.5x rifle triangles")
		var receiver: MeshInstance3D = gun.find_child("Receiver", true, false) as MeshInstance3D
		assert_gte(receiver.mesh.get_surface_count(), 3, path + " separates metal, polymer and secondary colour")
		var materials: Array[Material] = []
		for surface: int in receiver.mesh.get_surface_count():
			var mat: Material = receiver.mesh.surface_get_material(surface)
			if mat != null and not materials.has(mat):
				materials.append(mat)
		assert_gte(materials.size(), 3, path + " has at least three distinct material slots")
		gun.free()


func test_rebuilt_gun_animation_parts_have_independent_pivots() -> void:
	for path: String in [KESTREL, TALON]:
		var gun: Node3D = _load(path)
		var receiver: Node3D = gun.find_child("Receiver", true, false) as Node3D
		var magazine: MeshInstance3D = gun.find_child("Magazine", true, false) as MeshInstance3D
		var bolt: Node3D = gun.find_child("Bolt", true, false) as Node3D
		var handle: Node3D = gun.find_child("ChargingHandle", true, false) as Node3D
		assert_eq(magazine.get_parent(), receiver, path + " magazine is independent of the bolt")
		assert_eq(bolt.get_parent(), receiver, path + " bolt is independent of the magazine")
		assert_not_null(handle, path + " has a charging handle")
		if handle:
			assert_true(bolt.is_ancestor_of(handle), path + " charging handle follows the bolt")
		assert_lt(magazine.get_aabb().position.y, -0.08, path + " magazine extends below its well pivot")
		assert_almost_eq(magazine.get_aabb().end.y, 0.0, 0.035, path + " magazine pivot is at its feed end")
		assert_true(gun.scale.is_equal_approx(Vector3.ONE), path + " imports in metres without rescaling")
		gun.free()


func test_rebuilt_guns_use_dynamic_light_baking() -> void:
	for path: String in [KESTREL, TALON]:
		var settings: ConfigFile = ConfigFile.new()
		assert_eq(settings.load(path + ".import"), OK, path + " import settings are committed")
		assert_eq(settings.get_value("params", "meshes/light_baking"), 3, path + " receives dynamic probe lighting")


func _rearmost_scope_z(node: Node, xform: Transform3D) -> float:
	var here: Transform3D = xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
	var rear: float = -INF
	if node is MeshInstance3D:
		for vertex: Vector3 in (node as MeshInstance3D).mesh.get_faces():
			var p: Vector3 = here * vertex
			if p.y > SCOPE_BOTTOM and absf(p.x) < SCOPE_HALF_WIDTH:
				rear = maxf(rear, p.z)
	for child: Node in node.get_children():
		rear = maxf(rear, _rearmost_scope_z(child, here))
	return rear


func test_scope_display_sits_behind_the_rebuilt_eyepiece() -> void:
	for path: String in [RIFLE, TALON]:
		var gun: Node3D = _load(path)
		var rear: float = _rearmost_scope_z(gun, Transform3D.IDENTITY)
		assert_lt(rear, SCOPE_LENS_Z, path + " eyepiece stays in front of the picture-in-picture lens")
		gun.free()

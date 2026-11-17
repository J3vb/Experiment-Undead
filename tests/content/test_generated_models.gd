## Checks the models built by tools/assets/build_models.py: they import,
## have the right size and axes, and keep the parts code needs by name.
extends GutTest

const RIFLE: String = "res://assets/models/weapons/rifle_ar.glb"
const SHOTGUN: String = "res://assets/models/weapons/shotgun_brenner.glb"
const KESTREL: String = "res://assets/models/weapons/kestrel_smg.glb"
const TALON: String = "res://assets/models/weapons/talon_dmr.glb"
const HOLLIS: String = "res://assets/models/weapons/hollis_44.glb"
const MAKO: String = "res://assets/models/weapons/mako_pdw.glb"
const ATLAS: String = "res://assets/models/weapons/atlas_auto.glb"
const HALBERD: String = "res://assets/models/weapons/halberd_lmg.glb"
const CORVID: String = "res://assets/models/weapons/corvid_338.glb"
const WALL: String = "res://assets/models/kit/wall_panel.glb"
const ZOMBIES: String = "res://assets/models/zombies/%s.glb"
const ZOMBIE_PARTS: Array[String] = ["Body", "Eyes", "EyeL", "EyeR"]
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
	for part: String in ["Magazine", "Bolt", "Muzzle", "Barrel", "SightGlass", "ReticleMount"]:
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


func test_kestrel_has_moving_parts_and_a_red_dot() -> void:
	var gun: Node3D = _load(KESTREL)
	if gun == null:
		return
	var parts: Array[String] = [
		"Magazine", "Bolt", "Muzzle", "Barrel", "FoldingStock", "SightGlass", "ReticleMount", "Grip", "Trigger"
	]
	for part: String in parts:
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


func _zombie_material(mesh_node: MeshInstance3D) -> ShaderMaterial:
	return mesh_node.mesh.surface_get_material(0) as ShaderMaterial


func _check_zombie_finishes(zombie: Node3D) -> void:
	var head_value: float = -1.0
	var plain_colors: Array[Color] = []
	for node: Node in zombie.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var mat: ShaderMaterial = mesh.surface_get_material(surface) as ShaderMaterial
			assert_not_null(mat, "zombie surfaces use their procedural finish")
			if mat == null:
				continue
			assert_eq(mat.shader.resource_path, "res://assets/materials/zombie_finish.gdshader")
			var color: Color = mat.get_shader_parameter(&"albedo")
			if mat.resource_name.begins_with("ZombieSkinHead"):
				head_value = color.get_luminance()
			elif not mat.resource_name.begins_with("ZombieGlow"):
				plain_colors.append(color)
	assert_gt(head_value, 0.0, "zombie head retains its own light skin finish")
	for color: Color in plain_colors:
		assert_gt(head_value, color.get_luminance(), "head is the lightest nonemissive surface")


func _check_zombie(id: String) -> Node3D:
	var zombie: Node3D = _load(ZOMBIES % id)
	if zombie == null:
		return null
	add_child(zombie)
	for part: String in ZOMBIE_PARTS:
		assert_not_null(zombie.find_child(part, true, false), id + " has " + part)
	var skeletons: Array[Node] = zombie.find_children("*", "Skeleton3D", true, false)
	assert_eq(skeletons.size(), 1, id + " has one shared character skeleton")
	if skeletons.size() == 1:
		var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
		assert_eq(skeleton.get_bone_count(), 22, id + " keeps all character bones")
		skeleton.force_update_all_bone_transforms()
		var eyes: Node3D = zombie.find_child("Eyes", true, false) as Node3D
		var head: Vector3 = skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("head")).origin
		if eyes:
			assert_gt(eyes.global_position.z, head.z, id + " eyes face +Z")
	_check_zombie_finishes(zombie)
	var settings: ConfigFile = ConfigFile.new()
	assert_eq(settings.load((ZOMBIES % id) + ".import"), OK)
	assert_eq(settings.get_value("params", "meshes/light_baking"), 3)
	assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/zombie_finish_import.gd")
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
		assert_gt(float(_zombie_material(belly).get_shader_parameter(&"emission_strength")), 0.0, "belly glows")
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
	for path: String in [KESTREL, TALON, MAKO, ATLAS, HALBERD]:
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
	for path: String in [KESTREL, TALON, MAKO, ATLAS, HALBERD]:
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
	for path: String in [KESTREL, TALON, HOLLIS, MAKO, ATLAS, HALBERD, CORVID]:
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
	for path: String in [TALON, CORVID]:
		var gun: Node3D = _load(path)
		var rear: float = _rearmost_scope_z(gun, Transform3D.IDENTITY)
		assert_lt(rear, SCOPE_LENS_Z, path + " eyepiece stays in front of the picture-in-picture lens")
		gun.free()


func test_red_dots_sit_on_the_aiming_line() -> void:
	var models: Dictionary[String, String] = {
		"rifle_ar": "rifle_ar", "kestrel_smg": "kestrel_smg", "brenner_trench": "shotgun_brenner"
	}
	for id: String in models:
		var gun: Node3D = _load("res://assets/models/weapons/%s.glb" % models[id])
		var ads: WeaponData = load("res://content/weapons/%s.tres" % id) as WeaponData
		var eye: Vector3 = Vector3(0, -ads.ads_position.y, 0.5)
		var mount: Node3D = gun.find_child("ReticleMount", true, false) as Node3D
		var glass: MeshInstance3D = gun.find_child("SightGlass", true, false) as MeshInstance3D
		var dot: Vector3 = _global(mount)
		assert_almost_eq(dot.x, eye.x, 0.0005, id + " reticle is centred left to right")
		assert_almost_eq(dot.y, eye.y, 0.0005, id + " reticle is on the eye line")
		var view_blocked: bool = MeshChecks.blocks_segment(gun, eye, dot + Vector3(0, 0, 0.0005))
		assert_false(view_blocked, id + ": nothing blocks the view to the dot")
		var glass_box: AABB = _global_xform(glass) * glass.get_aabb()
		var behind_glass: bool = glass_box.has_point(Vector3(eye.x, eye.y, glass_box.get_center().z))
		assert_true(behind_glass, id + ": the dot sits behind the glass")
		assert_lt(dot.z, eye.z, id + ": the dot is in front of the eye")
		gun.free()


func _global_xform(node: Node3D) -> Transform3D:
	var xform: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent is Node3D:
		xform = (parent as Node3D).transform * xform
		parent = parent.get_parent()
	return xform


func _global(node: Node3D) -> Vector3:
	return _global_xform(node).origin

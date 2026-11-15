## Checks the five code-built Vault gun models (tools/assets/*_model.py): parts code
## finds by name, size and facing, few draw calls, and an open line through the sights.
extends GutTest

const MODEL: String = "res://assets/models/weapons/%s.glb"
## id: [length min, length max, parts code or tests need]
const GUNS: Dictionary = {
	&"hollis_44": [0.26, 0.34, ["Bolt", "Grip", "Trigger", "Muzzle"]],
	&"mako_pdw": [0.6, 0.72, ["Magazine", "Bolt", "ChargingHandle", "Stock", "IronSights", "Foregrip", "Muzzle"]],
	&"atlas_auto": [1.0, 1.15, ["Magazine", "Bolt", "ChargingHandle", "Stock", "Barrel", "IronSights", "Muzzle"]],
	&"halberd_lmg": [1.2, 1.32, ["Magazine", "Bolt", "Stock", "Barrel", "CarryHandle", "Bipod", "Muzzle"]],
	&"corvid_338":
	[1.3, 1.4, ["Magazine", "Bolt", "ChargingHandle", "Stock", "Optic", "OpticGlass", "ScopeLensMount", "MuzzleBrake"]],
}
const IRON_SIGHTS: Array[StringName] = [&"hollis_44", &"mako_pdw", &"atlas_auto", &"halberd_lmg"]


func _load(id: StringName) -> Node3D:
	var packed: PackedScene = load(MODEL % id) as PackedScene
	assert_not_null(packed, String(id) + " imports as a scene")
	return packed.instantiate() as Node3D if packed else null


func _bounds(node: Node, xform: Transform3D, out: Array[AABB]) -> void:
	var here: Transform3D = xform * (node as Node3D).transform if node is Node3D else xform
	if node is MeshInstance3D:
		var box: AABB = here * (node as MeshInstance3D).get_aabb()
		out[0] = box if out[0].size == Vector3.ZERO else out[0].merge(box)
	for child: Node in node.get_children():
		_bounds(child, here, out)


func _blocks_ray(node: Node, xform: Transform3D, from: Vector3) -> bool:
	var here: Transform3D = xform * (node as Node3D).transform if node is Node3D else xform
	if node is MeshInstance3D:
		var faces: PackedVector3Array = (node as MeshInstance3D).mesh.get_faces()
		for i: int in range(0, faces.size(), 3):
			var a: Vector3 = here * faces[i]
			var hit: Variant = Geometry3D.ray_intersects_triangle(
				from, Vector3.FORWARD, a, here * faces[i + 1], here * faces[i + 2]
			)
			if hit != null:
				return true
	for child: Node in node.get_children():
		if _blocks_ray(child, here, from):
			return true
	return false


func test_models_have_their_parts_and_point_forward() -> void:
	for id: StringName in GUNS:
		var gun: Node3D = _load(id)
		if gun == null:
			continue
		for part: String in GUNS[id][2]:
			assert_not_null(gun.find_child(part, true, false), "%s has %s" % [id, part])
		assert_true(gun.find_child("Receiver", true, false) is MeshInstance3D, String(id) + " static body joined")
		var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
		assert_lt(muzzle.position.z, -0.18, String(id) + " muzzle points forward (-Z)")
		var box: Array[AABB] = [AABB()]
		_bounds(gun, Transform3D.IDENTITY, box)
		assert_between(box[0].size.z, GUNS[id][0], GUNS[id][1], String(id) + " length")
		assert_lt(box[0].size.x, 0.12, String(id) + " is narrow")
		assert_lte(gun.find_children("*", "MeshInstance3D", true, false).size(), 12, String(id) + " few draw calls")
		gun.free()


func test_revolver_has_no_magazine_and_a_cocking_hammer() -> void:
	var gun: Node3D = _load(&"hollis_44")
	assert_null(gun.find_child("Magazine", true, false), "cylinder loads by hand")
	var hammer: Node3D = gun.find_child("Bolt", true, false) as Node3D
	assert_gt(hammer.position.z, 0.03, "hammer sits behind the cylinder")
	gun.free()


func test_iron_sight_line_is_open_at_the_ads_height() -> void:
	for id: StringName in IRON_SIGHTS:
		var gun: Node3D = _load(id)
		var ads: Vector3 = Content.weapon(id).ads_position
		var eye: Vector3 = Vector3(0, -ads.y + 0.003, 0.6)
		assert_false(_blocks_ray(gun, Transform3D.IDENTITY, eye), String(id) + " nothing blocks the sight picture")
		assert_true(
			_blocks_ray(gun, Transform3D.IDENTITY, Vector3(0, -ads.y - 0.004, 0.6)),
			String(id) + " a front post sits on the aiming line"
		)
		gun.free()


func test_corvid_scope_sits_on_the_ads_line() -> void:
	var gun: Node3D = _load(&"corvid_338")
	var mount: Node3D = gun.find_child("ScopeLensMount", true, false) as Node3D
	var ads: Vector3 = Content.weapon(&"corvid_338").ads_position
	assert_almost_eq(mount.position.y, -ads.y, 0.002, "scope centre on the ADS eye line")
	assert_almost_eq(mount.position.z, 0.128, 0.002, "rear lens where the viewmodels put the scope disc")
	gun.free()

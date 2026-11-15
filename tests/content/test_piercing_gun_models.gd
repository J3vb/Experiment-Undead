## Checks rifle silhouettes, animated parts, sights, model budget and dynamic imports.
extends GutTest

const GUNS: Dictionary = {
	&"fieldhand_lever":
	[1.03, 1.12, ["Bolt", "Stock", "Foregrip", "Barrel", "MagazineTube", "Lever", "IronSights", "Trigger", "Muzzle"]],
	&"ironwood_50":
	[
		1.45,
		1.6,
		["Magazine", "Bolt", "ChargingHandle", "Stock", "Optic", "OpticGlass", "ScopeLensMount", "MuzzleBrake"]
	],
}


func _load(id: StringName) -> Node3D:
	var scene: PackedScene = load("res://assets/models/weapons/%s.glb" % id) as PackedScene
	assert_not_null(scene)
	return scene.instantiate() as Node3D if scene else null


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
			var hit: Variant = Geometry3D.ray_intersects_triangle(
				from, Vector3.FORWARD, here * faces[i], here * faces[i + 1], here * faces[i + 2]
			)
			if hit != null:
				return true
	for child: Node in node.get_children():
		if _blocks_ray(child, here, from):
			return true
	return false


func test_models_have_their_named_parts_and_distinct_rifle_lengths() -> void:
	for id: StringName in GUNS:
		var gun: Node3D = _load(id)
		if gun == null:
			continue
		for part: String in GUNS[id][2]:
			assert_not_null(gun.find_child(part, true, false), "%s has %s" % [id, part])
		assert_true(gun.find_child("Receiver", true, false) is MeshInstance3D)
		var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
		assert_lt(muzzle.position.z, -0.18, String(id) + " faces -Z")
		var box: Array[AABB] = [AABB()]
		_bounds(gun, Transform3D.IDENTITY, box)
		assert_between(box[0].size.z, GUNS[id][0], GUNS[id][1])
		assert_lt(box[0].size.x, 0.12)
		assert_lte(gun.find_children("*", "MeshInstance3D", true, false).size(), 12)
		gun.free()


func test_fieldhand_tube_stays_in_place_and_iron_sights_are_open() -> void:
	var gun: Node3D = _load(&"fieldhand_lever")
	assert_null(gun.find_child("Magazine", true, false), "round reload never drops a detachable magazine")
	var ads: Vector3 = Content.weapon(&"fieldhand_lever").ads_position
	assert_false(_blocks_ray(gun, Transform3D.IDENTITY, Vector3(0, -ads.y + 0.003, 0.6)))
	assert_true(_blocks_ray(gun, Transform3D.IDENTITY, Vector3(0, -ads.y - 0.004, 0.6)))
	gun.free()


func test_ironwood_scope_matches_the_corvid_eye_line() -> void:
	var gun: Node3D = _load(&"ironwood_50")
	var mount: Node3D = gun.find_child("ScopeLensMount", true, false) as Node3D
	var ads: Vector3 = Content.weapon(&"ironwood_50").ads_position
	assert_almost_eq(mount.position.y, -ads.y, 0.002)
	assert_almost_eq(mount.position.z, 0.128, 0.002)
	gun.free()


func test_models_use_the_shared_finish_and_fit_the_triangle_budget() -> void:
	for id: StringName in GUNS:
		var gun: Node3D = _load(id)
		var triangles: int = 0
		for node: Node in gun.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			triangles += int(mesh.get_faces().size() / 3.0)
			for surface: int in mesh.get_surface_count():
				var material: Material = mesh.surface_get_material(surface)
				if material.resource_name != "OpticGlass":
					assert_true(material is ShaderMaterial, String(id) + " shared gun finish")
		assert_lte(triangles, 8000)
		var config: ConfigFile = ConfigFile.new()
		assert_eq(config.load("res://assets/models/weapons/%s.glb.import" % id), OK)
		assert_eq(config.get_value("params", "meshes/light_baking"), 3)
		gun.free()

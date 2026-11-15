## Both sidearms import at real scale with animated slides, magazines and clear sights.
extends GutTest

const MODELS: Dictionary = {
	&"warden_p9": [&"pistol_service", 0.21, 0.27],
	&"wren_mp": [&"wren_mp", 0.36, 0.50],
}
const PARTS: Array[String] = ["Receiver", "Grip", "Slide", "Bolt", "Magazine", "Trigger", "Muzzle"]


func _model(id: StringName) -> Node3D:
	var packed: PackedScene = load("res://assets/models/weapons/%s.glb" % id) as PackedScene
	assert_not_null(packed, String(id) + " imports as a scene")
	if packed == null:
		return null
	var model: Node3D = packed.instantiate() as Node3D
	add_child_autofree(model)
	return model


func _bounds(model: Node3D) -> AABB:
	var bounds: AABB = AABB()
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var relative: Transform3D = model.global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = relative * mesh.get_aabb()
		bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	return bounds


func _hits_sight_ray(model: Node3D, height: float) -> bool:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var origin: Vector3 = mesh.to_local(model.to_global(Vector3(0, height, 0.6)))
		var direction: Vector3 = mesh.global_basis.inverse() * model.global_basis * Vector3.FORWARD
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for index: int in range(0, faces.size(), 3):
			if (
				Geometry3D.ray_intersects_triangle(origin, direction, faces[index], faces[index + 1], faces[index + 2])
				!= null
			):
				return true
	return false


func test_sidearm_parts_scale_and_facing() -> void:
	for id: StringName in MODELS:
		var model: Node3D = _model(id)
		if model == null:
			continue
		for name: String in PARTS:
			assert_not_null(model.find_child(name, true, false), "%s has %s" % [id, name])
		assert_true(model.find_child("Receiver", true, false) is MeshInstance3D)
		assert_true(model.find_child("Slide", true, false) is MeshInstance3D)
		var muzzle: Node3D = model.find_child("Muzzle", true, false) as Node3D
		if muzzle:
			assert_lt(model.to_local(muzzle.global_position).z, -0.1, "muzzle points along Godot -Z")
		var box: AABB = _bounds(model)
		assert_between(box.size.z, MODELS[id][1], MODELS[id][2], String(id) + " length in metres")
		assert_lt(box.size.x, 0.08, String(id) + " narrow sidearm frame")
		assert_between(box.size.y, 0.12, 0.3, String(id) + " grip and magazine height")
		assert_lte(model.find_children("*", "MeshInstance3D", true, false).size(), 12, "bounded draw calls")


func test_runtime_bolt_drives_slide_independently_of_the_magazine() -> void:
	for id: StringName in MODELS:
		var model: Node3D = _model(id)
		var bolt: Node = model.find_child("Bolt", true, false)
		var slide: Node = model.find_child("Slide", true, false)
		var magazine: Node = model.find_child("Magazine", true, false)
		assert_true(bolt.is_ancestor_of(slide), String(id) + " shared bolt animation carries the slide")
		assert_false(bolt.is_ancestor_of(magazine), String(id) + " recoil leaves the magazine seated")
		assert_false(slide.is_ancestor_of(magazine), String(id) + " magazine reload moves separately")


func test_wren_has_a_hinged_brace_and_extended_magazine() -> void:
	var model: Node3D = _model(&"wren_mp")
	var brace: Node3D = model.find_child("Brace", true, false) as Node3D
	var cuff: Node3D = model.find_child("Stock", true, false) as Node3D
	var magazine: MeshInstance3D = model.find_child("Magazine", true, false) as MeshInstance3D
	assert_not_null(brace, "folding brace has its own hinge pivot")
	assert_not_null(cuff, "brace has a separate slotted cuff")
	if brace and cuff:
		assert_true(brace.is_ancestor_of(cuff), "cuff folds with the brace")
		assert_between(model.to_local(brace.global_position).z, 0.05, 0.15, "hinge at the rear of the frame")
	if magazine:
		assert_gt(magazine.get_aabb().size.y, 0.12, "extended twenty-round magazine projects below the grip")


func test_sidearms_keep_the_ads_line_clear_above_the_front_post() -> void:
	for id: StringName in MODELS:
		var model: Node3D = _model(id)
		var gun: WeaponData = Content.weapon(MODELS[id][0])
		var sight_height: float = -gun.ads_position.y
		assert_false(_hits_sight_ray(model, sight_height + 0.003), String(id) + " open sight picture")
		assert_true(_hits_sight_ray(model, sight_height - 0.004), String(id) + " front post marks the aiming line")


func test_sidearms_keep_the_weapon_detail_and_material_budgets() -> void:
	var rifle: Node3D = (load("res://assets/models/weapons/rifle_ar.glb") as PackedScene).instantiate() as Node3D
	add_child_autofree(rifle)
	var rifle_triangles: int = _triangles(rifle)
	for id: StringName in MODELS:
		var model: Node3D = _model(id)
		var triangles: int = _triangles(model)
		assert_gte(triangles, 4000, String(id) + " close-view mechanical detail")
		assert_lte(triangles, 8000, String(id) + " weapon triangle cap")
		assert_lte(triangles, int(rifle_triangles * 1.5), String(id) + " existing rifle-relative cap")
		var material_names: Array[String] = []
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for surface: int in mesh.get_surface_count():
				var material: Material = mesh.surface_get_material(surface)
				if not material_names.has(material.resource_name):
					material_names.append(material.resource_name)
		assert_lte(material_names.size(), 6, String(id) + " existing source material cap")


func _triangles(model: Node3D) -> int:
	var vertices: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		vertices += (node as MeshInstance3D).mesh.get_faces().size()
	return int(vertices / 3.0)


func test_sidearms_use_dynamic_lighting_and_the_shared_finish_import() -> void:
	for id: StringName in MODELS:
		var config: ConfigFile = ConfigFile.new()
		assert_eq(config.load("res://assets/models/weapons/%s.glb.import" % id), OK)
		assert_eq(config.get_value("params", "meshes/light_baking"), 3, "moves under dynamic probe lighting")
		assert_eq(config.get_value("params", "import_script/path"), "res://tools/assets/gun_finish_import.gd")
		var model: Node3D = _model(id)
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for surface: int in mesh.get_surface_count():
				var material: ShaderMaterial = mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(material, "procedural weapon finish replaces GLB materials")
				if material:
					assert_eq(material.shader.resource_path, "res://assets/materials/gun_finish.gdshader")

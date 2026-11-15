## Checks Bastion's belt-fed silhouette, moving parts, unobstructed sights and imported gun finishes.
extends GutTest

const MODEL: String = "res://assets/models/weapons/bastion_lmg.glb"
const VIEWMODEL: String = "res://systems/weapons/viewmodels/bastion_viewmodel.tscn"


func _load_model() -> Node3D:
	return (load(MODEL) as PackedScene).instantiate() as Node3D


func _bounds(node: Node, xform: Transform3D, out: Array[AABB]) -> void:
	var here: Transform3D = xform * (node as Node3D).transform if node is Node3D else xform
	if node is MeshInstance3D:
		var box: AABB = here * (node as MeshInstance3D).get_aabb()
		out[0] = box if out[0].size == Vector3.ZERO else out[0].merge(box)
	for child: Node in node.get_children():
		_bounds(child, here, out)


func _blocks_sight(node: Node, xform: Transform3D, height: float) -> bool:
	var here: Transform3D = xform * (node as Node3D).transform if node is Node3D else xform
	if node is MeshInstance3D:
		var faces: PackedVector3Array = (node as MeshInstance3D).mesh.get_faces()
		for index: int in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(
				Vector3(0, height, 0.6),
				Vector3.FORWARD,
				here * faces[index],
				here * faces[index + 1],
				here * faces[index + 2]
			)
			if hit != null:
				return true
	for child: Node in node.get_children():
		if _blocks_sight(child, here, height):
			return true
	return false


func test_belt_box_cover_and_folded_bipod_keep_their_parts_and_scale() -> void:
	var gun: Node3D = _load_model()
	for part: String in ["Belt", "FeedCover", "Magazine", "Bolt", "Muzzle", "Barrel", "Bipod", "CarryHandle", "Stock"]:
		var node: Node = gun.find_child(part, true, false)
		assert_not_null(node, "Bastion has a separate " + part)
		if node:
			assert_eq(node.get_parent().name, &"Receiver", part + " belongs to the receiver")
	var box: Array[AABB] = [AABB()]
	_bounds(gun, Transform3D.IDENTITY, box)
	assert_between(box[0].size.z, 1.3, 1.4, "long heavy gun")
	assert_between(box[0].size.x, 0.2, 0.28, "side-mounted belt box widens the silhouette")
	assert_lt((gun.find_child("Muzzle", true, false) as Node3D).position.z, -0.85, "muzzle faces -Z")
	var bipod: Array[AABB] = [AABB()]
	_bounds(gun.find_child("Bipod", true, false), Transform3D.IDENTITY, bipod)
	assert_lt(bipod[0].size.y, 0.06, "folded legs stay close to the barrel")
	assert_gt(bipod[0].size.z, 0.25, "legs run along the gun")
	assert_lte(gun.find_children("*", "MeshInstance3D", true, false).size(), 9, "bounded moving parts")
	gun.free()


func test_iron_sight_line_is_open_above_the_front_post() -> void:
	var gun: Node3D = _load_model()
	assert_false(_blocks_sight(gun, Transform3D.IDENTITY, 0.115), "cover and carry handle leave the sights open")
	assert_true(_blocks_sight(gun, Transform3D.IDENTITY, 0.108), "front post lies on the ADS sight line")
	gun.free()


func test_imported_geometry_keeps_the_budget_and_shared_finish() -> void:
	var gun: Node3D = _load_model()
	var triangles: int = 0
	for node: Node in gun.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		triangles += int(mesh_node.mesh.get_faces().size() / 3.0)
		assert_eq(mesh_node.gi_mode, GeometryInstance3D.GI_MODE_DYNAMIC)
		for surface: int in mesh_node.mesh.get_surface_count():
			var finish: ShaderMaterial = mesh_node.mesh.surface_get_material(surface) as ShaderMaterial
			assert_not_null(finish, "gun surfaces use the procedural finish")
			if finish:
				assert_eq(finish.shader.resource_path, "res://assets/materials/gun_finish.gdshader")
	assert_lte(triangles, 8000, "within the weapon triangle budget")
	gun.free()
	var settings: ConfigFile = ConfigFile.new()
	assert_eq(settings.load(MODEL + ".import"), OK)
	assert_true(settings.get_value("params", "meshes/generate_lods"))
	assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/gun_finish_import.gd")


func _inlay_areas(mesh: Mesh) -> Vector2:
	var areas: Vector2 = Vector2.ZERO
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index: int in range(0, indices.size(), 3):
			var a: int = indices[index]
			var b: int = indices[index + 1]
			var c: int = indices[index + 2]
			var area: float = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).length() * 0.5
			areas.y += area
			if colors[a].a < 0.5 or colors[b].a < 0.5 or colors[c].a < 0.5:
				areas.x += area
	return areas


func test_rarity_mask_remains_a_thin_inlay() -> void:
	var gun: Node3D = _load_model()
	var areas: Vector2 = Vector2.ZERO
	for node: Node in gun.find_children("*", "MeshInstance3D", true, false):
		areas += _inlay_areas((node as MeshInstance3D).mesh)
	assert_gt(areas.x, 0.0, "Bastion has a rarity inlay")
	assert_lt(areas.x / areas.y, 0.02, "rarity covers less than two percent of the gun")
	gun.free()


func test_viewmodel_has_muzzle_effects_and_a_quiet_spin_up_layer() -> void:
	var viewmodel: Node = (load(VIEWMODEL) as PackedScene).instantiate()
	assert_not_null(viewmodel.find_child("FlashLight", true, false))
	assert_not_null(viewmodel.find_child("FlashMesh", true, false))
	var audio: AudioStreamPlayer = viewmodel.find_child("SpinUpAudio", true, false) as AudioStreamPlayer
	assert_not_null(audio)
	if audio:
		assert_eq(audio.stream.resource_path, "res://assets/audio/bastion_spin_up.wav")
		assert_eq(audio.bus, &"Weapons")
		assert_false(audio.autoplay)
		assert_lte(audio.volume_db, -20.0)
	viewmodel.free()

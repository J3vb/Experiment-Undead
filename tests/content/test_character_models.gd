## Character imports preserve the shared rig, skin, scale and matching forearm envelopes.
extends GutTest

const PLAYER: String = "res://assets/models/characters/player.glb"
const VESTS: Array[String] = ["light", "medium", "heavy"]
const GEAR_SHADER: String = "res://assets/materials/gear.gdshader"
const GEAR_IMPORTER: GDScript = preload("res://tools/assets/gear_import.gd")
const ARMS: String = "res://assets/models/characters/player_arms.glb"
const BONES: Array[String] = [
	"pelvis",
	"spine_01",
	"spine_02",
	"spine_03",
	"neck",
	"head",
	"clavicle_L",
	"upperarm_L",
	"forearm_L",
	"hand_L",
	"thigh_L",
	"shin_L",
	"foot_L",
	"clavicle_R",
	"upperarm_R",
	"forearm_R",
	"hand_R",
	"thigh_R",
	"shin_R",
	"foot_R",
	"sock_thigh_R",
	"sock_back",
]


func _character(path: String = PLAYER) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, path + " imports as a PackedScene")
	if packed == null:
		return null
	var model: Node3D = packed.instantiate() as Node3D
	add_child_autofree(model)
	return model


func _skeleton(model: Node3D) -> Skeleton3D:
	var found: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	assert_eq(found.size(), 1, "one shared character skeleton")
	return found[0] as Skeleton3D if found.size() == 1 else null


func _assert_shared_bones(model: Node3D) -> void:
	if model == null:
		return
	var skeleton: Skeleton3D = _skeleton(model)
	if skeleton == null:
		return
	assert_eq(skeleton.get_bone_count(), 22, "no missing bones or exporter helper bones")
	for bone: String in BONES:
		assert_gte(skeleton.find_bone(bone), 0, "shared rig includes " + bone)
	assert_eq(skeleton.get_bone_parent(skeleton.find_bone("sock_back")), skeleton.find_bone("spine_03"))
	assert_eq(skeleton.get_bone_parent(skeleton.find_bone("sock_thigh_R")), skeleton.find_bone("thigh_R"))


func test_player_preserves_all_22_bone_names() -> void:
	_assert_shared_bones(_character())


func test_first_person_arms_import_preserves_all_22_bone_names() -> void:
	_assert_shared_bones(_character(ARMS))


func test_player_import_contains_skinned_geometry_at_adult_scale() -> void:
	var model: Node3D = _character()
	if model == null:
		return
	var skeleton: Skeleton3D = _skeleton(model)
	var bounds: AABB = AABB()
	var first: bool = true
	var skinned: bool = false
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == skeleton:
			skinned = true
		for vertex: Vector3 in mesh.mesh.get_faces():
			var point: Vector3 = mesh.global_transform * vertex
			bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
			first = false
	assert_false(first, "model has visible geometry")
	assert_true(skinned, "a MeshInstance3D is skinned to the character skeleton")
	assert_between(bounds.size.y, 1.75, 1.85, "undersuit player is about 1.80 m tall")
	assert_almost_eq(bounds.position.y, 0.0, 0.01, "boot soles rest on the origin")
	assert_true(model.scale.is_equal_approx(Vector3.ONE), "metres need no instance rescaling")


func test_player_faces_positive_z_with_eyes_on_the_head() -> void:
	var model: Node3D = _character()
	if model == null:
		return
	var skeleton: Skeleton3D = _skeleton(model)
	var eyes: Node3D = model.find_child("Eyes", true, false) as Node3D
	assert_not_null(eyes, "Eyes marker survives glTF import")
	if skeleton == null or eyes == null:
		return
	var head: Vector3 = skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("head")).origin
	assert_gt(eyes.global_position.z, head.z + 0.04, "goggles and Eyes face Godot +Z")
	assert_between(eyes.global_position.y, 1.65, 1.77, "Eyes sits at goggle height")
	var attachment: BoneAttachment3D = eyes.get_parent() as BoneAttachment3D
	assert_not_null(attachment, "Eyes follows a BoneAttachment3D")
	if attachment:
		assert_eq(attachment.bone_name, "head", "head poses carry the eye marker")


func test_player_uses_dynamic_lighting_and_gear_import() -> void:
	var settings: ConfigFile = ConfigFile.new()
	assert_eq(settings.load(PLAYER + ".import"), OK, "player import settings are committed")
	assert_eq(settings.get_value("params", "meshes/light_baking"), 3)
	assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/gear_import.gd")


func _assert_materials_have_gear_finish(model: Node3D) -> void:
	if model == null:
		return
	var surfaces: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var material: ShaderMaterial = mesh.surface_get_material(surface) as ShaderMaterial
			assert_not_null(material, "%s surface %d uses a ShaderMaterial" % [node.name, surface])
			if material == null:
				continue
			surfaces += 1
			assert_eq(material.shader.resource_path, GEAR_SHADER)
			assert_true(GEAR_IMPORTER.FINISHES.has(material.resource_name), material.resource_name + " is known")
			assert_eq(material.get_shader_parameter(&"finish"), GEAR_IMPORTER.FINISHES.get(material.resource_name))
	assert_gt(surfaces, 0, "character contains finished surfaces")
	assert_push_error_count(0, "known character materials import without fallback errors")


func test_every_player_material_uses_the_gear_shader_and_a_known_finish() -> void:
	_assert_materials_have_gear_finish(_character())


func test_every_first_person_arm_material_uses_the_gear_shader_and_a_known_finish() -> void:
	_assert_materials_have_gear_finish(_character(ARMS))


func _triangle_radius(points: PackedVector3Array, center: Vector3, axis: Vector3) -> float:
	var radius: float = 0.0
	for edge: int in range(3):
		var start: Vector3 = points[edge]
		var finish: Vector3 = points[(edge + 1) % 3]
		var distance_start: float = (start - center).dot(axis)
		var distance_finish: float = (finish - center).dot(axis)
		if distance_start * distance_finish > 0.0 or is_equal_approx(distance_start, distance_finish):
			continue
		var crossing: Vector3 = start.lerp(finish, distance_start / (distance_start - distance_finish))
		var distance: float = crossing.distance_to(center)
		if distance < 0.15:
			radius = maxf(radius, distance)
	return radius


func _forearm_radius(model: Node3D, side: String, fraction: float) -> float:
	var skeleton: Skeleton3D = _skeleton(model)
	if skeleton == null:
		return 0.0
	var head: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("forearm_" + side)).origin
	var tail: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("hand_" + side)).origin
	head = skeleton.global_transform * head
	tail = skeleton.global_transform * tail
	var center: Vector3 = head.lerp(tail, fraction)
	var axis: Vector3 = (tail - head).normalized()
	var radius: float = 0.0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for index: int in range(0, faces.size(), 3):
			var triangle: PackedVector3Array = PackedVector3Array()
			for corner: int in range(3):
				triangle.append(mesh.global_transform * faces[index + corner])
			radius = maxf(radius, _triangle_radius(triangle, center, axis))
	return radius


func test_first_person_forearms_fit_the_same_vest_cuffs_as_the_world_body() -> void:
	var body: Node3D = _character()
	var arms: Node3D = _character(ARMS)
	if body == null or arms == null:
		return
	for side: String in ["L", "R"]:
		for fraction: float in [0.4, 0.6, 0.8]:
			var body_radius: float = _forearm_radius(body, side, fraction)
			var arms_radius: float = _forearm_radius(arms, side, fraction)
			assert_gt(body_radius, 0.02, "world body has a forearm section")
			assert_gt(arms_radius, 0.02, "first-person arms have a forearm section")
			assert_almost_eq(arms_radius, body_radius, 0.005, side + " forearm radius matches within 5 mm")


func test_first_person_arms_are_skinned_and_use_dynamic_lighting() -> void:
	var model: Node3D = _character(ARMS)
	if model == null:
		return
	var skeleton: Skeleton3D = _skeleton(model)
	var skinned: bool = false
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == skeleton:
			skinned = true
	assert_true(skinned, "first-person arm geometry is skinned to the shared skeleton")
	var settings: ConfigFile = ConfigFile.new()
	assert_eq(settings.load(ARMS + ".import"), OK, "first-person arm import settings are committed")
	assert_eq(settings.get_value("params", "meshes/light_baking"), 3)
	assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/gear_import.gd")


func _vest(frame: String) -> Node3D:
	var packed: PackedScene = load("res://assets/models/gear/vest_%s.glb" % frame) as PackedScene
	assert_not_null(packed, frame + " vest imports")
	if packed == null:
		return null
	var model: Node3D = packed.instantiate() as Node3D
	add_child_autofree(model)
	return model


func test_vests_preserve_required_nodes_and_shared_skin() -> void:
	for frame: String in VESTS:
		var vest: Node3D = _vest(frame)
		if vest == null:
			continue
		var skeleton: Skeleton3D = _skeleton(vest)
		var shell: MeshInstance3D = vest.find_child("Shell", true, false) as MeshInstance3D
		assert_not_null(shell, frame + " Shell exists")
		assert_not_null(vest.find_child("CharmClip", true, false), frame + " chest charm clip exists")
		if shell == null or skeleton == null:
			continue
		assert_eq(skeleton.get_bone_count(), 22, frame + " has exactly 22 bones")
		for bone: String in BONES:
			assert_gte(skeleton.find_bone(bone), 0, frame + " has " + bone)
		assert_not_null(shell.skin, frame + " Shell has a skin")
		assert_eq(shell.get_node_or_null(shell.skeleton), skeleton, frame + " Shell resolves its skeleton")
		for cuff_name: String in ["CuffFP_L", "CuffFP_R"]:
			var cuff: MeshInstance3D = vest.find_child(cuff_name, true, false) as MeshInstance3D
			assert_not_null(cuff, frame + " separate " + cuff_name)
			if cuff:
				assert_null(cuff.skin, "first-person cuff is unskinned")
				assert_lt(cuff.get_aabb().get_center().length(), 0.005, "cuff origin is at its mesh centre")


func test_vests_import_dynamic_lighting_and_four_gear_finishes() -> void:
	for frame: String in VESTS:
		var settings: ConfigFile = ConfigFile.new()
		var path: String = "res://assets/models/gear/vest_%s.glb" % frame
		assert_eq(settings.load(path + ".import"), OK)
		assert_eq(settings.get_value("params", "meshes/light_baking"), 3)
		assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/gear_import.gd")
		var vest: Node3D = _vest(frame)
		if vest == null:
			continue
		for node: Node in vest.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for surface: int in mesh.get_surface_count():
				var material: ShaderMaterial = mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(material, "gear import applies the zone shader")
				if material:
					assert_eq(material.shader.resource_path, "res://assets/materials/gear.gdshader")
					assert_true(material.resource_name in ["GearFabric", "GearWebbing", "GearPlate", "GearPolymer"])


func _skin_vertex(shell: MeshInstance3D, skeleton: Skeleton3D, surface: int, vertex: int) -> Vector3:
	var arrays: Array = shell.mesh.surface_get_arrays(surface)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var result: Vector3 = Vector3.ZERO
	var influences: int = weights.size() / positions.size()
	for influence: int in influences:
		var index: int = vertex * influences + influence
		var bind: int = bones[index]
		var name: StringName = shell.skin.get_bind_name(bind)
		var bone: int = skeleton.find_bone(name) if name != &"" else shell.skin.get_bind_bone(bind)
		var transform: Transform3D = skeleton.get_bone_global_pose(bone) * shell.skin.get_bind_pose(bind)
		result += transform * positions[vertex] * weights[index]
	return result


func _posed_displacement(shell: MeshInstance3D, skeleton: Skeleton3D, bone: int) -> float:
	var before: Array[PackedVector3Array] = []
	for surface: int in shell.mesh.get_surface_count():
		var positions: PackedVector3Array = shell.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		var points: PackedVector3Array = []
		for vertex: int in positions.size():
			points.append(_skin_vertex(shell, skeleton, surface, vertex))
		before.append(points)
	skeleton.set_bone_pose_rotation(bone, Quaternion(Vector3.RIGHT, 0.35))
	skeleton.force_update_all_bone_transforms()
	var displacement: float = 0.0
	for surface: int in shell.mesh.get_surface_count():
		for vertex: int in before[surface].size():
			var point: Vector3 = _skin_vertex(shell, skeleton, surface, vertex)
			assert_true(point.is_finite(), "retargeted skin produces finite vertex positions")
			displacement = maxf(displacement, point.distance_to(before[surface][vertex]))
	skeleton.reset_bone_pose(bone)
	skeleton.force_update_all_bone_transforms()
	return displacement


func test_vest_shell_rebinds_to_player_and_deforms_with_spine_and_forearm() -> void:
	for frame: String in VESTS:
		var player: Node3D = _character()
		var vest: Node3D = _vest(frame)
		if player == null or vest == null:
			continue
		var body_rig: Skeleton3D = _skeleton(player)
		var shell: MeshInstance3D = vest.find_child("Shell", true, false) as MeshInstance3D
		if body_rig == null or shell == null or shell.skin == null:
			continue
		shell.skeleton = shell.get_path_to(body_rig)
		assert_eq(shell.get_node_or_null(shell.skeleton), body_rig, frame + " uses the player's skeleton")
		for bone_name: String in ["spine_02", "forearm_L"]:
			var bone: int = body_rig.find_bone(bone_name)
			assert_gt(_posed_displacement(shell, body_rig, bone), 0.005, frame + " deforms with " + bone_name)
		await get_tree().process_frame
		assert_eq(shell.get_node_or_null(shell.skeleton), body_rig, "binding remains valid after a frame")

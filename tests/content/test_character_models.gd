## Character imports preserve the shared rig, skin, scale and matching forearm envelopes.
extends GutTest

const ASSEMBLY: Script = preload("res://tools/gear_booth_assembly.gd")
const PLAYER: String = "res://assets/models/characters/player.glb"
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


func test_all_ten_rigid_gear_models_import_with_required_parts_and_budgets() -> void:
	for id: String in ASSEMBLY.GEAR:
		var packed: PackedScene = load("res://assets/models/gear/%s.glb" % id) as PackedScene
		assert_not_null(packed, id + " imports")
		if packed == null:
			continue
		var model: Node3D = packed.instantiate() as Node3D
		add_child_autofree(model)
		var required: Array[String] = ["Module", "Port"]
		var lower: int = 1000
		var upper: int = 1500
		if id.begins_with("charm_"):
			required = ["Hook", "Link1", "Link2", "Body"]
			lower = 600
			upper = 800
		for part: String in required:
			assert_not_null(model.find_child(part, true, false), id + " keeps " + part)
		var triangles: int = 0
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			triangles += (node as MeshInstance3D).mesh.get_faces().size() / 3
		assert_between(triangles, lower, upper, id + " keeps the close-up triangle budget")
		var settings: ConfigFile = ConfigFile.new()
		assert_eq(settings.load("res://assets/models/gear/%s.glb.import" % id), OK)
		assert_eq(settings.get_value("params", "meshes/light_baking"), 3, id + " uses dynamic lighting")
		assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/gear_import.gd")


func test_booth_gear_follows_bones_with_a_transformed_character() -> void:
	var display: Node3D = ASSEMBLY.build_character()
	display.transform = Transform3D(Basis(Vector3.UP, 0.63), Vector3(2.0, 0.5, -3.0))
	add_child_autofree(display)
	await get_tree().process_frame
	await get_tree().process_frame
	var skeleton: Skeleton3D = display.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_assert_attached_within(display, skeleton, "Module", "forearm_L")
	_assert_attached_within(display, skeleton, "Port", "neck")
	var clip: Node3D = display.find_child("CharmClip", true, false) as Node3D
	var hook: Node3D = display.find_child("Hook", true, false) as Node3D
	var body: Node3D = display.find_child("Body", true, false) as Node3D
	var vest: Node3D = display.find_child("MediumVest", true, false) as Node3D
	assert_not_null(vest, "booth includes the imported medium vest")
	var shell: MeshInstance3D = vest.find_child("Shell", true, false) as MeshInstance3D if vest != null else null
	assert_not_null(shell, "medium vest keeps its skinned shell")
	if shell != null:
		assert_eq(shell.get_node_or_null(shell.skeleton), skeleton, "vest shell uses the displayed player's rig")
	assert_not_null(clip, "vest provides its CharmClip")
	assert_not_null(hook, "charm keeps the hook pivot")
	assert_not_null(body, "charm keeps its hanging body")
	if clip != null and hook != null:
		assert_lt(hook.global_position.distance_to(clip.global_position), 0.001, "charm hangs from CharmClip")
	if body != null and hook != null:
		assert_lt(body.global_position.y, hook.global_position.y - 0.015, "charm hangs down below the clip")
	var forearm: int = skeleton.find_bone("forearm_L")
	var pose: Transform3D = skeleton.get_bone_pose(forearm)
	pose.basis = pose.basis * Basis(Vector3.RIGHT, 0.3)
	skeleton.set_bone_pose(forearm, pose)
	await get_tree().process_frame
	_assert_attached_within(display, skeleton, "Module", "forearm_L")


func _assert_attached_within(display: Node3D, skeleton: Skeleton3D, part: String, bone: String) -> void:
	var mesh: Node3D = display.find_child(part, true, false) as Node3D
	assert_not_null(mesh, "booth includes " + part)
	if mesh == null:
		return
	var attachment: BoneAttachment3D = mesh.get_parent() as BoneAttachment3D
	assert_not_null(attachment, part + " uses BoneAttachment3D")
	if attachment == null:
		return
	assert_eq(attachment.bone_name, bone)
	var target: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
	assert_lt(mesh.global_position.distance_to(target), 0.03, part + " origin sits within 3 cm of " + bone)

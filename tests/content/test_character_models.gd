## The player import preserves the shared rig, skin, scale and forward eye marker.
extends GutTest

const PLAYER: String = "res://assets/models/characters/player.glb"
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


func _player() -> Node3D:
	var packed: PackedScene = load(PLAYER) as PackedScene
	assert_not_null(packed, "player.glb imports as a PackedScene")
	if packed == null:
		return null
	var model: Node3D = packed.instantiate() as Node3D
	add_child_autofree(model)
	return model


func _skeleton(model: Node3D) -> Skeleton3D:
	var found: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	assert_eq(found.size(), 1, "one shared character skeleton")
	return found[0] as Skeleton3D if found.size() == 1 else null


func test_player_preserves_all_22_bone_names() -> void:
	var model: Node3D = _player()
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


func test_player_import_contains_skinned_geometry_at_adult_scale() -> void:
	var model: Node3D = _player()
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
	var model: Node3D = _player()
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


func test_player_uses_dynamic_lighting_and_vertex_shading_import() -> void:
	var settings: ConfigFile = ConfigFile.new()
	assert_eq(settings.load(PLAYER + ".import"), OK, "player import settings are committed")
	assert_eq(settings.get_value("params", "meshes/light_baking"), 3)
	assert_eq(settings.get_value("params", "import_script/path"), "res://tools/assets/vertex_shading_import.gd")

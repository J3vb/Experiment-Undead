## Vest imports keep their shared skeleton, shader finishes and deformation after retargeting.
extends GutTest

const PLAYER: String = "res://assets/models/characters/player.glb"
const VESTS: Array[String] = ["light", "medium", "heavy"]
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


func _skin_vertex(shell: MeshInstance3D, skeleton: Skeleton3D, arrays: Array, vertex: int) -> Vector3:
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
	var surfaces: Array[Array] = []
	var before: Array[PackedVector3Array] = []
	for surface: int in shell.mesh.get_surface_count():
		var arrays: Array = shell.mesh.surface_get_arrays(surface)
		surfaces.append(arrays)
		var points: PackedVector3Array = []
		for vertex: int in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
			points.append(_skin_vertex(shell, skeleton, arrays, vertex))
		before.append(points)
	skeleton.set_bone_pose_rotation(bone, Quaternion(Vector3.RIGHT, 0.35))
	skeleton.force_update_all_bone_transforms()
	var displacement: float = 0.0
	for surface: int in shell.mesh.get_surface_count():
		for vertex: int in before[surface].size():
			var point: Vector3 = _skin_vertex(shell, skeleton, surfaces[surface], vertex)
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


func test_every_vest_visual_scene_has_both_first_person_cuffs() -> void:
	for id: StringName in Content.sorted_ids(&"gear_visuals"):
		var visual: GearVisual = Content.get_item(&"gear_visuals", id) as GearVisual
		if visual.slot != &"vest":
			continue
		var scenes: Array[PackedScene] = [visual.scene]
		scenes.append_array(visual.tier_scenes)
		for scene: PackedScene in scenes:
			var vest: Node3D = scene.instantiate() as Node3D
			for cuff_name: String in ["CuffFP_L", "CuffFP_R"]:
				assert_not_null(
					vest.find_child(cuff_name, true, false), "%s %s has %s" % [id, scene.resource_path, cuff_name]
				)
			vest.free()

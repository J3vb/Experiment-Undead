## Worn gear uses body bones, real rarity finishes and a shadow-only owner view.
extends GutTest

const BODY: PackedScene = preload("res://assets/models/characters/player.glb")


func test_apply_attaches_one_piece_per_slot_on_the_expected_body_bones() -> void:
	var rig: GearRig = _rig()
	var bones: Dictionary[StringName, StringName] = {&"charm": &"spine_03", &"implant": &"forearm_L"}
	rig.apply(_mixed_look())
	for slot: StringName in CharacterLook.SLOTS:
		var holder: Node3D = rig.skeleton.get_node(String(slot).capitalize()) as Node3D
		assert_eq(holder.get_child_count(), 1, "one equipped scene per filled slot")
		assert_same(holder.get_parent(), rig.skeleton)
		if bones.has(slot):
			assert_eq((holder as BoneAttachment3D).bone_name, bones[slot], String(slot) + " follows its body bone")
		else:
			assert_false(holder is BoneAttachment3D, "the skinned vest is not moved by a bone a second time")
	assert_eq(_equipped_count(rig), 3)


func test_reapplying_replaces_pieces_and_empty_slots_remove_them() -> void:
	var rig: GearRig = _rig()
	rig.apply(_mixed_look())
	var previous: Node = rig.skeleton.get_node("Vest")
	rig.apply(_mixed_look())
	assert_false(is_instance_valid(previous), "old scene is removed before attaching the new one")
	assert_eq(_equipped_count(rig), 3, "reapply does not duplicate gear")
	rig.apply(LookBuilder.from_equipped({"charm": {"base": "charm_dog_tags", "rar": "common"}}))
	assert_eq(_equipped_count(rig), 1)
	assert_null(rig.skeleton.get_node_or_null("Vest"))
	assert_null(rig.skeleton.get_node_or_null("Implant"))
	rig.apply(CharacterLook.new())
	assert_eq(_equipped_count(rig), 0, "an empty loadout removes all pieces")


func test_rarity_trim_and_dyes_reach_each_equipped_piece() -> void:
	var rig: GearRig = _rig()
	var look: CharacterLook = _mixed_look()
	look.slots[&"charm"]["dyes"] = [Color("cdeee8"), Color("5f6d68")]
	rig.apply(look)
	for slot: StringName in CharacterLook.SLOTS:
		var piece: Node = rig.skeleton.get_node(String(slot).capitalize()).get_child(0)
		var entry: Dictionary = look.slots[slot]
		var finish: RarityLook = load("res://content/looks/rarity/%s.tres" % entry["rarity"]) as RarityLook
		for node: Node in piece.find_children("*", "GeometryInstance3D", true, false):
			var geometry: GeometryInstance3D = node as GeometryInstance3D
			assert_eq(geometry.get_instance_shader_parameter(&"trim_color"), finish.trim_color)
			assert_eq(geometry.get_instance_shader_parameter(&"glow_strength"), finish.glow_strength)
			assert_eq(geometry.get_instance_shader_parameter(&"dye_main"), entry["dyes"][0])
			assert_eq(geometry.get_instance_shader_parameter(&"dye_accent"), entry["dyes"][1])


func test_unknown_or_wrong_slot_visual_uses_base_mesh_in_common() -> void:
	var rig: GearRig = _rig()
	var look: CharacterLook = _mixed_look()
	look.slots[&"vest"]["visual_id"] = &"unknown_vest"
	look.slots[&"charm"]["visual_id"] = &"vest_heavy"
	rig.apply(look)
	var common: RarityLook = load("res://content/looks/rarity/common.tres") as RarityLook
	for slot: StringName in [&"vest", &"charm"]:
		var piece: Node = rig.skeleton.get_node(String(slot).capitalize()).get_child(0)
		assert_eq(piece.scene_file_path, GearVisual.fallback(slot).scene.resource_path)
		for node: Node in piece.find_children("*", "GeometryInstance3D", true, false):
			var geometry: GeometryInstance3D = node as GeometryInstance3D
			assert_eq(geometry.get_instance_shader_parameter(&"trim_color"), common.trim_color)
			assert_eq(geometry.get_instance_shader_parameter(&"glow_strength"), 0.0)


func test_vest_uses_body_skin_without_socket_offset_or_first_person_cuff_duplicates() -> void:
	var rig: GearRig = _rig()
	rig.apply(_mixed_look())
	await wait_process_frames(1)
	var vest: Node = rig.skeleton.get_node("Vest").get_child(0)
	var shell: MeshInstance3D = vest.find_child("Shell", true, false) as MeshInstance3D
	assert_same(shell.get_node(shell.skeleton), rig.skeleton, "vest bends on the body's skeleton")
	assert_true(shell.global_transform.is_equal_approx(rig.skeleton.global_transform), "skin stays in body space")
	var spine: int = rig.skeleton.find_bone("spine_02")
	rig.skeleton.set_bone_pose_position(spine, rig.skeleton.get_bone_pose_position(spine) + Vector3(0.0, -0.3, 0.1))
	rig.skeleton.set_bone_pose_rotation(spine, Quaternion(Vector3.RIGHT, 0.6))
	await wait_process_frames(1)
	assert_true(shell.global_transform.is_equal_approx(rig.skeleton.global_transform), "posed body moves the skin once")
	assert_null(vest.find_child("CuffFP_L", true, false))
	assert_null(vest.find_child("CuffFP_R", true, false))
	for node: Node in vest.find_children("*", "BoneAttachment3D", true, false):
		var attachment: BoneAttachment3D = node as BoneAttachment3D
		assert_true(attachment.use_external_skeleton)
		assert_same(attachment.get_node(attachment.external_skeleton), rig.skeleton)


func test_arms_are_lowered_for_previews_without_a_body_animator() -> void:
	var rig: GearRig = _rig()
	for side: String in ["L", "R"]:
		var shoulder: Vector3 = rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone("upperarm_" + side)).origin
		var hand: Vector3 = rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone("hand_" + side)).origin
		assert_lt(hand.y, shoulder.y - 0.55, "arms hang down")
		assert_almost_eq(hand.x, shoulder.x, 0.001, "hands are under the shoulders")


func test_owner_body_and_new_pieces_cast_shadows_without_drawing_in_first_person() -> void:
	var rig: GearRig = _rig()
	rig.set_owner_view(true)
	rig.apply(_mixed_look())
	for node: Node in rig.body.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		assert_eq(geometry.layers, 1, "owner remains on the lit world layer so its shadow renders")
		assert_eq(geometry.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	rig.set_owner_view(false)
	for node: Node in rig.body.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		assert_eq(geometry.layers, 1, "teammates stay on the world camera layer")
		assert_eq(geometry.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


func test_every_registered_visual_attaches_at_body_scale() -> void:
	var rig: GearRig = _rig()
	assert_eq(Content.ids(&"gear_visuals").size(), 13, "three vest frames, five charms and five implants")
	for visual_id: StringName in Content.ids(&"gear_visuals"):
		var visual: GearVisual = GearVisual.find(visual_id)
		assert_not_null(visual.scene, String(visual_id))
		assert_ne(rig.skeleton.find_bone(visual.attach), -1, String(visual_id) + " has a body bone")
		var look: CharacterLook = CharacterLook.new()
		look.slots[visual.slot] = {"visual_id": visual_id, "rarity": &"common"}
		rig.apply(look)
		var piece: Node = rig.skeleton.get_node(String(visual.slot).capitalize()).get_child(0)
		for node: Node in piece.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node as MeshInstance3D
			if mesh.is_queued_for_deletion():
				continue
			var center: Vector3 = rig.body.to_local(mesh.global_transform * mesh.get_aabb().get_center())
			assert_between(center.y, 0.8, 1.7, String(visual_id) + " sits on the upper body")
			assert_lt(absf(center.x), 0.7, String(visual_id) + " stays within the body silhouette")
			assert_lt(absf(center.z), 0.4, String(visual_id) + " does not float in front of the body")


func test_implant_module_follows_forearm_and_port_follows_neck_independently() -> void:
	var rig: GearRig = _rig()
	rig.apply(_mixed_look())
	await wait_process_frames(1)
	var implant: Node = rig.skeleton.get_node("Implant").get_child(0)
	var module: MeshInstance3D = implant.find_child("Module", true, false) as MeshInstance3D
	var port: MeshInstance3D = implant.find_child("Port", true, false) as MeshInstance3D
	var neck_attachment: BoneAttachment3D = port.get_parent() as BoneAttachment3D
	assert_not_null(neck_attachment, "neck port has its own attachment inside the equipped implant")
	assert_eq(neck_attachment.bone_name, &"neck")
	assert_true(neck_attachment.use_external_skeleton)
	assert_same(neck_attachment.get_node(neck_attachment.external_skeleton), rig.skeleton)
	var forearm: int = rig.skeleton.find_bone("forearm_L")
	var neck: int = rig.skeleton.find_bone("neck")
	var neck_before: Transform3D = port.global_transform
	var module_before: Transform3D = module.global_transform
	var module_origin: Vector3 = rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(forearm).origin
	assert_almost_eq(module.global_position.distance_to(module_origin), 0.0, 0.001)
	assert_true(module.global_basis.is_equal_approx(rig.body.global_basis), "lowered-arm module faces forward")
	rig.skeleton.set_bone_pose_rotation(
		forearm, rig.skeleton.get_bone_pose_rotation(forearm) * Quaternion(Vector3.RIGHT, 0.4)
	)
	rig.skeleton.force_update_all_bone_transforms()
	await wait_process_frames(1)
	assert_false(module.global_basis.is_equal_approx(module_before.basis), "module turns with the forearm")
	assert_true(port.global_transform.is_equal_approx(neck_before), "forearm motion leaves the neck port in place")
	var module_after: Transform3D = module.global_transform
	rig.skeleton.set_bone_pose_rotation(
		neck, rig.skeleton.get_bone_pose_rotation(neck) * Quaternion(Vector3.RIGHT, 0.3)
	)
	rig.skeleton.force_update_all_bone_transforms()
	await wait_process_frames(1)
	assert_false(port.global_basis.is_equal_approx(neck_before.basis), "port turns with the neck")
	assert_true(module.global_transform.is_equal_approx(module_after), "neck motion leaves the forearm module in place")
	var neck_origin: Vector3 = rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(neck).origin
	assert_almost_eq(port.global_position.distance_to(neck_origin), 0.0, 0.001)


func _rig() -> GearRig:
	var body: Node3D = BODY.instantiate() as Node3D
	body.rotation.y = PI
	var rig: GearRig = GearRig.new()
	rig.body = body
	body.add_child(rig)
	add_child_autofree(body)
	return rig


func _mixed_look() -> CharacterLook:
	return (
		LookBuilder
		. from_equipped(
			{
				"vest": {"base": "vest_medium", "rar": "rare"},
				"charm": {"base": "charm_dog_tags", "rar": "epic"},
				"implant": {"base": "implant_reflex", "rar": "legendary"},
			}
		)
	)


func _equipped_count(rig: GearRig) -> int:
	var count: int = 0
	for slot: StringName in CharacterLook.SLOTS:
		if rig.skeleton.get_node_or_null(String(slot).capitalize()) != null:
			count += 1
	return count

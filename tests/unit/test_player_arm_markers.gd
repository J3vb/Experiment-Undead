## Imported tip markers stay at actual morphed glove cap centres after weapon changes and skinning.
extends GutTest


func _holder() -> WeaponHolder:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	var holder: WeaponHolder = WeaponHolder.new()
	camera.add_child(holder)
	holder.setup(null, camera)
	holder.set_process(false)
	return holder


func _hand_points(view: PlayerArmView, side: String) -> PackedVector3Array:
	var bind: int = -1
	var hand: int = view.skeleton.find_bone("hand_" + side)
	for index: int in view.mesh.skin.get_bind_count():
		if view.mesh.skin.get_bind_name(index) == "hand_" + side:
			bind = index
	assert_gte(bind, 0, side + " hand skin binding exists")
	var transform: Transform3D = view.skeleton.get_bone_global_pose(hand) * view.mesh.skin.get_bind_pose(bind)
	var mesh: ArrayMesh = view.mesh.mesh as ArrayMesh
	var morph: int = view.mesh.find_blend_shape_by_name(view.profile.morph) if not view.profile.morph.is_empty() else -1
	var result: PackedVector3Array = []
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if morph >= 0:
			var shape: PackedVector3Array = mesh.surface_get_blend_shape_arrays(surface)[morph][Mesh.ARRAY_VERTEX]
			for index: int in vertices.size():
				vertices[index] = (
					shape[index]
					if mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED
					else vertices[index] + shape[index]
				)
		result.append_array(_surface_hand_points(arrays, vertices, bind, transform))
	return result


func _surface_hand_points(
	arrays: Array, vertices: PackedVector3Array, bind: int, transform: Transform3D
) -> PackedVector3Array:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / vertices.size()
	var result: PackedVector3Array = []
	for index: int in vertices.size():
		for influence: int in influences:
			var slot: int = index * influences + influence
			if bones[slot] == bind and weights[slot] > .99:
				result.append(transform * vertices[index])
	return result


func _assert_tip(view: PlayerArmView, name: String, points: PackedVector3Array) -> void:
	var marker: Node3D = view.find_child(name, true, false) as Node3D
	var position: Vector3 = view.skeleton.to_local(marker.global_position)
	var cap: Dictionary[Vector3i, Vector3] = {}
	for point: Vector3 in points:
		if point.distance_to(position) < .0022:
			cap[Vector3i((point * 1000000).round())] = point
	var label: String = String(view.profile.id) + " " + name
	assert_gte(cap.size(), 10, label + " is inside its twelve-sided fingertip cap")
	if cap.is_empty():
		return
	var center: Vector3 = Vector3.ZERO
	for point: Vector3 in cap.values():
		center += point
	assert_lt(position.distance_to(center / cap.size()), .0002, label + " follows the actual cap centre")


func _assert_profile(holder: WeaponHolder, id: StringName) -> void:
	var weapon: Weapon = holder.give(Content.weapon(id))
	weapon.set_process(false)
	holder.arm_view.set_process(false)
	await get_tree().process_frame
	for side: String in ["R", "L"]:
		var points: PackedVector3Array = _hand_points(holder.arm_view, side)
		_assert_tip(holder.arm_view, "GripIndexTip_" + side, points)
		_assert_tip(holder.arm_view, "GripThumbTip_" + side, points)


func test_rifle_base_markers_match_imported_skinned_cap_centres() -> void:
	await _assert_profile(_holder(), &"rifle_ar")


func test_all_grip_markers_match_morphed_skinned_cap_centres_and_reset_to_rifle() -> void:
	var holder: WeaponHolder = _holder()
	for id: StringName in PlayerArmProfiles.weapon_ids():
		await _assert_profile(holder, id)
	await _assert_profile(holder, &"rifle_ar")

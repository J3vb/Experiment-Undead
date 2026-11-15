## Runtime grips must keep the imported joints anatomical as the weapon moves.
extends GutTest

const PLAYER: PackedScene = preload("res://assets/models/characters/player.glb")


func _weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	var seen: Array[PackedScene] = []
	var ids: Array = Content.ids(&"weapons")
	ids.sort()
	for id: StringName in ids:
		var data: WeaponData = Content.weapon(id)
		if data.viewmodel_scene != null and not seen.has(data.viewmodel_scene):
			seen.append(data.viewmodel_scene)
			result.append(data)
	assert_gt(result.size(), 0, "anatomy checks must exercise the shipped weapon roster")
	return result


func _holder(data: WeaponData) -> WeaponHolder:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	camera.current = true
	var holder: WeaponHolder = WeaponHolder.new()
	camera.add_child(holder)
	holder.setup(null, camera)
	holder.give(data)
	holder.set_process(false)
	holder.current.set_process(false)
	holder.arm_view.set_process(false)
	return holder


func _dorsal(skeleton: Skeleton3D, bone: int) -> Vector3:
	var rotation: Basis = (
		skeleton.get_bone_global_pose(bone).basis * skeleton.get_bone_global_rest(bone).basis.inverse()
	)
	return (rotation * Vector3.FORWARD).normalized()


func _angles(skeleton: Skeleton3D, side: String) -> Dictionary[String, float]:
	var upper: int = skeleton.find_bone("upperarm_" + side)
	var forearm: int = skeleton.find_bone("forearm_" + side)
	var hand: int = skeleton.find_bone("hand_" + side)
	var shoulder: Vector3 = skeleton.get_bone_global_pose(upper).origin
	var elbow: Vector3 = skeleton.get_bone_global_pose(forearm).origin
	var wrist: Vector3 = skeleton.get_bone_global_pose(hand).origin
	var forward: Vector3 = (wrist - elbow).normalized()
	var palm: Vector3 = skeleton.get_bone_global_pose(hand).basis.y.normalized()
	var dorsal: Vector3 = _dorsal(skeleton, forearm)
	var lateral: Vector3 = dorsal.cross(forward).normalized()
	var transported: Vector3 = Basis(Quaternion(forward, palm)) * dorsal
	return {
		"wrist": rad_to_deg(forward.angle_to(palm)),
		"flex": rad_to_deg(atan2(palm.dot(dorsal), palm.dot(forward))),
		"deviation": rad_to_deg(atan2(palm.dot(lateral), palm.dot(forward))),
		"roll": rad_to_deg(transported.signed_angle_to(_dorsal(skeleton, hand), palm)),
		"elbow": rad_to_deg((elbow - shoulder).normalized().angle_to(forward)),
	}


func _assert_angles(skeleton: Skeleton3D, side: String, context: String) -> void:
	var angles: Dictionary[String, float] = _angles(skeleton, side)
	var label: String = "%s %s %s" % [context, side, angles]
	for angle: String in angles:
		assert_true(is_finite(angles[angle]), label + " finite " + angle)
	assert_lte(angles.wrist, 35.0, label + " total wrist bend")
	assert_lte(absf(angles.flex), 30.0, label + " wrist flexion")
	assert_lte(absf(angles.deviation), 20.0, label + " lateral wrist deviation")
	assert_lte(absf(angles.roll), 20.0, label + " wrist roll")
	assert_between(angles.elbow, 45.0, 145.0, label + " elbow neither locks nor folds back")
	for bone: String in ["upperarm_", "forearm_", "hand_"]:
		var basis: Basis = skeleton.get_bone_global_pose(skeleton.find_bone(bone + side)).basis
		assert_almost_eq(basis.determinant(), 1.0, 0.0001, label + " positive unit bone rotation")
	for bone: String in ["forearm_", "hand_"]:
		var index: int = skeleton.find_bone(bone + side)
		var parent: int = skeleton.get_bone_parent(index)
		var start: Vector3 = skeleton.get_bone_global_pose(parent).origin
		var end: Vector3 = skeleton.get_bone_global_pose(index).origin
		var length: float = skeleton.get_bone_rest(index).origin.length()
		assert_almost_eq(start.distance_to(end), length, 0.0001, label + " segment length remains anatomical")


func _assert_shoulders(holder: WeaponHolder, side: String, context: String) -> void:
	var body: Node3D = PLAYER.instantiate() as Node3D
	add_child(body)
	var eyes: Node3D = body.find_child("Eyes", true, false) as Node3D
	var skeleton: Skeleton3D = holder.arm_view.skeleton
	var camera: Camera3D = holder.get_parent() as Camera3D
	var upper: int = skeleton.find_bone("upperarm_" + side)
	var rest: Vector3 = skeleton.get_bone_global_rest(upper).origin
	var reference: Vector3 = Basis(Vector3.UP, PI) * (rest - eyes.global_position)
	var frame: Transform3D = camera.global_transform.affine_inverse() * skeleton.global_transform
	assert_almost_eq(frame.basis.determinant(), 1.0, 0.0001, context + " arm instance is not mirrored or scaled")
	var shoulder: Vector3 = frame * skeleton.get_bone_global_pose(upper).origin
	var elbow: Vector3 = frame * skeleton.get_bone_global_pose(skeleton.find_bone("forearm_" + side)).origin
	var wrist: Vector3 = frame * skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + side)).origin
	var offset: Vector3 = shoulder - reference
	var label: String = "%s %s shoulder offset %s" % [context, side, offset]
	assert_lte(absf(offset.x), 0.08, label + " lateral body allowance")
	assert_lte(absf(offset.y), 0.08, label + " vertical body allowance")
	assert_lte(absf(offset.z), 0.15, label + " fore/aft body allowance")
	assert_gt(elbow.x * (1.0 if side == "R" else -1.0), 0.0, label + " elbow remains on its own torso side")
	assert_lte(elbow.y, shoulder.y + 0.015, label + " elbow stays below shoulder")
	assert_gt(wrist.y, elbow.y, label + " hand reaches up from elbow")
	body.free()


func _assert_pose(holder: WeaponHolder, context: String) -> void:
	holder.current._process(0.05)
	holder.arm_view.update_pose()
	assert_not_null(holder.arm_view.skeleton, context + " imported skeleton exists")
	for side: String in ["R", "L"]:
		_assert_angles(holder.arm_view.skeleton, side, context)
		_assert_shoulders(holder, side, context)


func test_every_weapon_keeps_anatomical_hip_and_ads_joints() -> void:
	for data: WeaponData in _weapons():
		var holder: WeaponHolder = _holder(data)
		var previous: float = 0.0
		holder.current.aiming = true
		for blend: float in [0.0, 0.5, 1.0]:
			holder.current.tick(data.ads_time * (blend - previous))
			_assert_pose(holder, "%s ADS %.2f" % [data.id, blend])
			previous = blend
		holder.get_parent().free()


func test_every_weapon_keeps_anatomical_reload_and_sprint_joints() -> void:
	for data: WeaponData in _weapons():
		var holder: WeaponHolder = _holder(data)
		var weapon: Weapon = holder.current
		weapon.instance.ammo_in_mag = 0
		assert_true(weapon.start_reload(), String(data.id) + " empty reload starts")
		var previous: float = 0.0
		for fraction: float in [0.25, 0.5, 0.75, 1.01]:
			weapon.tick(weapon._reload_duration * (fraction - previous))
			_assert_pose(holder, "%s reload %.2f" % [data.id, fraction])
			previous = fraction
		if weapon.is_reloading():
			weapon.tick(weapon._reload_duration * data.magazine_size)
		assert_false(weapon.is_reloading(), String(data.id) + " all inserts complete before sprint")
		weapon.sprinting = true
		weapon.tick(1.0)
		_assert_pose(holder, String(data.id) + " sprint")
		holder.get_parent().free()


func _assert_motion_continuity(holder: WeaponHolder, phase: String) -> void:
	var weapon: Weapon = holder.current
	if phase == "ADS":
		weapon.aiming = true
	else:
		weapon.instance.ammo_in_mag = 0
		assert_true(weapon.start_reload())
	var duration: float = weapon.data.ads_time if phase == "ADS" else weapon._reload_duration
	var inserts: int = weapon.data.magazine_size if phase == "reload" and weapon.data.reload_per_round else 1
	var delta: float = duration / 400.0
	var positions: Array[Vector3] = []
	var rotations: Array[Quaternion] = []
	for step: int in 400 * inserts + 1:
		if step > 0:
			weapon.tick(delta)
		weapon._process(delta)
		holder.arm_view.update_pose()
		var skeleton: Skeleton3D = holder.arm_view.skeleton
		for side: int in 2:
			var bone: String = "forearm_R" if side == 0 else "forearm_L"
			var pose: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone(bone))
			var rotation: Quaternion = pose.basis.get_rotation_quaternion()
			if step == 0:
				positions.append(pose.origin)
				rotations.append(rotation)
			else:
				var label: String = "%s %s %s step %d" % [weapon.data.id, bone, phase, step]
				assert_lte(positions[side].distance_to(pose.origin), 0.04, label + " elbow does not jump between poles")
				assert_lte(rad_to_deg(rotations[side].angle_to(rotation)), 15.0, label + " forearm roll does not flip")
				positions[side] = pose.origin
				rotations[side] = rotation


func test_every_weapon_keeps_elbows_and_forearm_roll_continuous_during_ads_and_reload() -> void:
	for data: WeaponData in _weapons():
		for phase: String in ["ADS", "reload"]:
			var holder: WeaponHolder = _holder(data)
			_assert_motion_continuity(holder, phase)
			holder.get_parent().free()


func test_every_weapon_keeps_anatomical_joints_through_actual_firing_kick() -> void:
	for data: WeaponData in _weapons():
		var holder: WeaponHolder = _holder(data)
		var weapon: Weapon = holder.current
		for aiming: bool in [false, true]:
			weapon.aiming = aiming
			weapon.tick(data.ads_time)
			_assert_pose(holder, String(data.id) + " before firing")
			weapon.fire()
			for frame: int in 12:
				weapon.tick(1.0 / 120.0)
				weapon._process(1.0 / 120.0)
				holder.arm_view.update_pose()
				var context: String = "%s fire ADS %s frame %d" % [data.id, aiming, frame]
				for side: String in ["R", "L"]:
					_assert_angles(holder.arm_view.skeleton, side, context)
					_assert_shoulders(holder, side, context)
		holder.get_parent().free()

## PlayerArmPose keeps imported segment lengths even at a parallel palm/reach-axis singularity.
extends GutTest


func test_parallel_palm_and_reach_axes_keep_both_arm_segments_and_hand_targets() -> void:
	var arms: Node3D = PlayerArmView.ARMS.instantiate() as Node3D
	add_child_autofree(arms)
	var skeleton: Skeleton3D = arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var solver: PlayerArmPose = PlayerArmPose.new(skeleton)
	var profile: PlayerArmProfiles.Profile = PlayerArmProfiles.profile(Content.weapon(&"rifle_ar"))
	profile.hip_position = Vector3.ZERO
	var grips: Array[PlayerArmProfiles.Hand] = [profile.right, profile.left]
	var sides: Array[String] = ["R", "L"]
	for index: int in sides.size():
		var hand: int = skeleton.find_bone("hand_" + sides[index])
		var palm: Vector3 = grips[index].rotation * skeleton.get_bone_global_rest(hand).basis.y
		grips[index].wrist = grips[index].shoulder + palm.normalized() * .4
	solver.pose(profile, Transform3D.IDENTITY)
	for index: int in sides.size():
		var hand: int = skeleton.find_bone("hand_" + sides[index])
		assert_almost_eq(skeleton.get_bone_global_pose(hand).origin, grips[index].wrist, Vector3.ONE * .00001)
		for name: String in ["forearm_", "hand_"]:
			var bone: int = skeleton.find_bone(name + sides[index])
			var parent: int = skeleton.get_bone_parent(bone)
			var start: Vector3 = skeleton.get_bone_global_pose(parent).origin
			var pose: Transform3D = skeleton.get_bone_global_pose(bone)
			assert_almost_eq(start.distance_to(pose.origin), skeleton.get_bone_rest(bone).origin.length(), .00001)
			assert_almost_eq(pose.basis.determinant(), 1.0, .0001)


func test_stock_sprint_shoulders_advance_and_lower_without_losing_hand_contact() -> void:
	for id: StringName in [&"brenner_trench", &"coachman_2b"]:
		var camera: Camera3D = Camera3D.new()
		add_child_autofree(camera)
		var holder: WeaponHolder = WeaponHolder.new()
		camera.add_child(holder)
		holder.setup(null, camera)
		holder.give(Content.weapon(id))
		holder.set_process(false)
		holder.current.set_process(false)
		holder.arm_view.set_process(false)
		var weapon: Weapon = holder.current
		var skeleton: Skeleton3D = holder.arm_view.skeleton
		var shoulder_bone: int = skeleton.find_bone("upperarm_R")
		var hand_bone: int = skeleton.find_bone("hand_R")
		var initial: Vector3 = skeleton.get_bone_global_pose(shoulder_bone).origin
		for active: bool in [true, false]:
			weapon.sprinting = active
			weapon.tick(1.0)
			weapon._process(1.0)
			holder.arm_view.update_pose()
			var shoulder: Vector3 = skeleton.get_bone_global_pose(shoulder_bone).origin
			if active:
				assert_lt(shoulder.z, initial.z - .07, String(id) + " shoulder advances beside the turned stock")
				assert_lt(shoulder.y, initial.y - .02, String(id) + " shoulder lowers beneath the turned stock")
			else:
				assert_almost_eq(shoulder, initial, Vector3.ONE * .00001, String(id) + " hip shoulder returns exactly")
			var target: Vector3 = weapon.transform * holder.arm_view.profile.right.wrist
			assert_almost_eq(skeleton.get_bone_global_pose(hand_bone).origin, target, Vector3.ONE * .00001)

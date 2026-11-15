## PlayerArmPose keeps imported segment lengths even at a parallel palm/reach-axis singularity.
extends GutTest


func test_parallel_palm_and_reach_axes_keep_both_arm_segments_and_hand_targets() -> void:
	var arms: Node3D = PlayerArmView.ARMS.instantiate() as Node3D
	add_child_autofree(arms)
	var skeleton: Skeleton3D = arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var solver: PlayerArmPose = PlayerArmPose.new(skeleton)
	var profile: PlayerArmProfiles.Profile = PlayerArmProfiles.profile(&"rifle_ar")
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

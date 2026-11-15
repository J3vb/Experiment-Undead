## Inspection posing preserves the imported skeleton's scale and reaches the requested wrist.
extends GutTest

const REVIEW: Script = preload("res://tools/character_review.gd")
const ARMS: PackedScene = preload("res://assets/models/characters/player_arms.glb")


func test_inspection_pose_reaches_wrist_without_scaling_bones() -> void:
	var arms: Node3D = ARMS.instantiate() as Node3D
	add_child_autofree(arms)
	var skeleton: Skeleton3D = arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var shoulder: Vector3 = Vector3(0.20, 0.015, -0.21)
	var wrist: Vector3 = Vector3(0.17, 0.39, -0.055)
	REVIEW._pose_arm(skeleton, "R", shoulder, wrist, Vector3(1, 0, -0.25))
	var upper: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("upperarm_R"))
	var lower: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("forearm_R"))
	var hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("hand_R"))
	assert_almost_eq(upper.origin, Vector3(0.20, -0.21, -0.015), Vector3.ONE * 0.00001)
	assert_almost_eq(hand.origin, Vector3(0.17, -0.055, -0.39), Vector3.ONE * 0.00001)
	assert_almost_eq(upper.origin.distance_to(lower.origin), 0.31112698, 0.00001)
	assert_almost_eq(lower.origin.distance_to(hand.origin), 0.28284271, 0.00001)
	for transform: Transform3D in [upper, lower, hand]:
		assert_almost_eq(transform.basis.get_scale(), Vector3.ONE, Vector3.ONE * 0.00001)
		assert_almost_eq(transform.basis.determinant(), 1.0, 0.00001)


func test_inspection_pose_leaves_the_other_arm_in_rest() -> void:
	var arms: Node3D = ARMS.instantiate() as Node3D
	add_child_autofree(arms)
	var skeleton: Skeleton3D = arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var left: int = skeleton.find_bone("hand_L")
	var before: Transform3D = skeleton.get_bone_global_pose(left)
	REVIEW._pose_arm(skeleton, "R", Vector3(0.20, 0.015, -0.21), Vector3(0.17, 0.39, -0.055), Vector3(1, 0, -0.25))
	assert_eq(skeleton.get_bone_global_pose(left), before)


func test_rifle_pose_preserves_both_arm_lengths_and_positive_unit_scale() -> void:
	var arms: Node3D = ARMS.instantiate() as Node3D
	add_child_autofree(arms)
	var skeleton: Skeleton3D = arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for side: String in ["R", "L"]:
		REVIEW._rifle_arm(skeleton, side)
		var upper_id: int = skeleton.find_bone("upperarm_" + side)
		var lower_id: int = skeleton.find_bone("forearm_" + side)
		var hand_id: int = skeleton.find_bone("hand_" + side)
		var upper: Transform3D = skeleton.get_bone_global_pose(upper_id)
		var lower: Transform3D = skeleton.get_bone_global_pose(lower_id)
		var hand: Transform3D = skeleton.get_bone_global_pose(hand_id)
		assert_almost_eq(
			upper.origin.distance_to(lower.origin), skeleton.get_bone_rest(lower_id).origin.length(), 0.00001
		)
		assert_almost_eq(
			lower.origin.distance_to(hand.origin), skeleton.get_bone_rest(hand_id).origin.length(), 0.00001
		)
		for transform: Transform3D in [upper, lower, hand]:
			assert_almost_eq(transform.basis.get_scale(), Vector3.ONE, Vector3.ONE * 0.00001)
			assert_almost_eq(transform.basis.determinant(), 1.0, 0.00001)

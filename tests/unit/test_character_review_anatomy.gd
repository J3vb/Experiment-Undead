## Inspect actual joint angles so weapon contact cannot conceal a bent or twisted wrist.
extends GutTest

const REVIEW: Script = preload("res://tools/character_review.gd")
const ARMS: PackedScene = preload("res://assets/models/characters/player_arms.glb")
const PLAYER: PackedScene = preload("res://assets/models/characters/player.glb")


func _dorsal(skeleton: Skeleton3D, bone: int) -> Vector3:
	var rotation: Basis = (
		skeleton.get_bone_global_pose(bone).basis * skeleton.get_bone_global_rest(bone).basis.inverse()
	)
	return (rotation * Vector3.FORWARD).normalized()


func _joint_angles(skeleton: Skeleton3D, side: String) -> Dictionary[String, float]:
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
	var hand_dorsal: Vector3 = _dorsal(skeleton, hand)
	return {
		"wrist": rad_to_deg(forward.angle_to(palm)),
		"flex": rad_to_deg(atan2(palm.dot(dorsal), palm.dot(forward))),
		"deviation": rad_to_deg(atan2(palm.dot(lateral), palm.dot(forward))),
		"roll": rad_to_deg(transported.signed_angle_to(hand_dorsal, palm)),
		"elbow": rad_to_deg((elbow - shoulder).normalized().angle_to(forward)),
	}


func test_rifle_grasps_keep_both_wrists_relaxed_and_elbows_bent() -> void:
	var arms: Node3D = ARMS.instantiate() as Node3D
	add_child_autofree(arms)
	var skeleton: Skeleton3D = arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for side: String in ["R", "L"]:
		REVIEW._rifle_arm(skeleton, side)
		var angles: Dictionary[String, float] = _joint_angles(skeleton, side)
		gut.p(
			(
				"%s wrist %.2f / flex %.2f / deviation %.2f / roll %.2f / elbow %.2f degrees"
				% [side, angles.wrist, angles.flex, angles.deviation, angles.roll, angles.elbow]
			)
		)
		for label: String in angles:
			assert_true(is_finite(angles[label]), side + " " + label + " angle must be finite")
		assert_lte(angles.wrist, 35.0, side + " palm must continue the forearm without a sharp wrist bend")
		assert_lte(absf(angles.flex), 30.0, side + " wrist flexion or extension")
		assert_lte(absf(angles.deviation), 20.0, side + " lateral wrist deviation")
		assert_lte(absf(angles.roll), 20.0, side + " hand inherits forearm roll instead of twisting at the wrist")
		assert_between(angles.elbow, 45.0, 145.0, side + " elbow must neither lock nor fold back on itself")


func test_virtual_shoulders_stay_near_the_body_relative_to_its_eyes() -> void:
	var body: Node3D = PLAYER.instantiate() as Node3D
	var arms: Node3D = ARMS.instantiate() as Node3D
	add_child_autofree(body)
	add_child_autofree(arms)
	var eyes: Node3D = body.find_child("Eyes", true, false) as Node3D
	var skeleton: Skeleton3D = arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for side: String in ["R", "L"]:
		var shoulder: int = skeleton.find_bone("upperarm_" + side)
		var rest: Vector3 = skeleton.get_bone_global_rest(shoulder).origin
		var reference: Vector3 = Basis(Vector3.UP, PI) * (rest - eyes.global_position)
		REVIEW._rifle_arm(skeleton, side)
		var posed_shoulder: Vector3 = skeleton.get_bone_global_pose(shoulder).origin
		var elbow: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("forearm_" + side)).origin
		var wrist: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + side)).origin
		var offset: Vector3 = posed_shoulder - reference
		gut.p("%s shoulder offset from body at eye camera: %s metres" % [side, offset])
		assert_lte(absf(offset.x), 0.08, side + " shoulder width stays consistent with the body")
		assert_lte(absf(offset.y), 0.08, side + " shoulder height stays consistent with the body")
		assert_lte(absf(offset.z), 0.15, side + " fore/aft viewmodel allowance must not hide an unreachable grip")
		assert_gt(elbow.x * (1.0 if side == "R" else -1.0), 0.0, side + " elbow stays on its own side of the torso")
		assert_lte(elbow.y, posed_shoulder.y + 0.015, side + " elbow stays below the shoulder")
		assert_gt(wrist.y, elbow.y, side + " hand reaches up from the elbow toward the rifle")

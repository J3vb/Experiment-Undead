## Review captures retain actual gameplay distances and bend the shared worn skeleton.
extends GutTest

const REVIEW: Script = preload("res://tools/vest_review.gd")
const ASSEMBLY: Script = preload("res://tools/gear_booth_assembly.gd")


func test_distance_cameras_use_measured_range_and_gameplay_fov() -> void:
	var orbit: Node3D = Node3D.new()
	var camera: Camera3D = Camera3D.new()
	orbit.add_child(camera)
	autofree(orbit)
	for distance: float in [10.0, 30.0]:
		REVIEW.frame_camera(camera, orbit, distance, 180.0)
		assert_eq(camera.keep_aspect, Camera3D.KEEP_WIDTH)
		assert_eq(camera.fov, 110.0)
		assert_almost_eq(camera.position.length(), distance, 0.001)
		assert_almost_eq(orbit.rotation.y, PI, 0.001)
	REVIEW.frame_camera(camera, orbit, 1.65, 0.0)
	assert_eq(camera.keep_aspect, Camera3D.KEEP_HEIGHT)
	assert_eq(camera.fov, 36.0)


func test_bent_pose_uses_player_skeleton_and_resets_to_rest() -> void:
	var player: Node3D = (load(ASSEMBLY.PLAYER) as PackedScene).instantiate() as Node3D
	add_child_autofree(player)
	var vest: Node3D = ASSEMBLY.attach_vest(player, "heavy")
	var skeleton: Skeleton3D = player.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var shell: MeshInstance3D = vest.find_child("Shell", true, false) as MeshInstance3D
	assert_eq(shell.get_node(shell.skeleton), skeleton, "the worn vest follows the posed player")
	var spine: int = skeleton.find_bone("spine_02")
	var rest: Quaternion = skeleton.get_bone_pose_rotation(spine)
	REVIEW.apply_pose(player, true)
	assert_gt(rest.angle_to(skeleton.get_bone_pose_rotation(spine)), 0.15)
	REVIEW.apply_pose(player, false)
	assert_almost_eq(rest.angle_to(skeleton.get_bone_pose_rotation(spine)), 0.0, 0.001)

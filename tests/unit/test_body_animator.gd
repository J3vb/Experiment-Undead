## BodyAnimator picks the clip for each move state from measured movement, crouch and downed.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player
var animator: BodyAnimator


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	animator = player.get_node("Body/BodyAnimator") as BodyAnimator
	animator.headless = false
	add_child_autofree(player)
	player.set_physics_process(false)
	player.camera.current = false


func _move(velocity: Vector3, frames: int = 40) -> void:
	for _frame: int in frames:
		await get_tree().physics_frame
		player.global_position += velocity * get_physics_process_delta_time()


func _ground() -> Vector2:
	return animator.tree.get(BodyAnimator.GROUND_BLEND)


func _state() -> String:
	return animator.tree.get(BodyAnimator.STATE_CURRENT)


func test_standing_still_plays_idle() -> void:
	await _move(Vector3.ZERO, 10)
	assert_eq(_state(), "ground")
	assert_almost_eq(_ground().length(), 0.0, 0.01, "idle sits at the blend origin")


func test_walk_directions_pick_their_clip() -> void:
	var cases: Dictionary[String, Vector3] = {
		"forward": Vector3(0.0, 0.0, -5.0),
		"back": Vector3(0.0, 0.0, 5.0),
		"right": Vector3(5.0, 0.0, 0.0),
		"left": Vector3(-5.0, 0.0, 0.0),
	}
	var expected: Dictionary[String, Vector2] = {
		"forward": Vector2(0.0, 1.0), "back": Vector2(0.0, -1.0), "right": Vector2(1.0, 0.0), "left": Vector2(-1.0, 0.0)
	}
	for direction: String in cases:
		await _move(cases[direction])
		assert_almost_eq(_ground().distance_to(expected[direction]), 0.0, 0.05, direction + " walk blend point")


func test_moves_are_measured_in_the_body_frame_after_turning() -> void:
	player.rotation.y = PI / 2.0
	await _move(Vector3(-5.0, 0.0, 0.0))
	assert_almost_eq(_ground().distance_to(Vector2(0.0, 1.0)), 0.0, 0.05, "walking where the body faces is forward")


func test_sprint_speed_reaches_the_run_clip_and_speeds_it_up() -> void:
	await _move(Vector3(0.0, 0.0, -player.sprint_speed))
	assert_almost_eq(_ground().y, player.sprint_speed / player.walk_speed, 0.05, "run blend point")
	assert_gt(animator.tree.get(BodyAnimator.TIME_SCALE), 1.0, "run clip speeds up to match the ground")


func test_crouch_and_crouch_walk() -> void:
	player.is_crouching = true
	await _move(Vector3.ZERO, 10)
	await wait_seconds(BodyAnimator.FADE_TIME)
	assert_eq(_state(), "crouch")
	assert_almost_eq(animator.tree.get(BodyAnimator.CROUCH_BLEND), 0.0, 0.01, "crouch idle")
	await _move(Vector3(0.0, 0.0, -player.walk_speed * player.crouch_speed_multiplier))
	assert_almost_eq(animator.tree.get(BodyAnimator.CROUCH_BLEND), 1.0, 0.05, "crouch walk")


func test_downed_wins_over_crouch_and_crawls_when_moving() -> void:
	player.is_crouching = true
	player.is_downed = true
	await _move(Vector3.ZERO, 10)
	assert_eq(_state(), "downed")
	await _move(Vector3(0.0, 0.0, -player.walk_speed * BodyAnimator.DOWNED_SPEED_SHARE))
	assert_almost_eq(animator.tree.get(BodyAnimator.DOWNED_BLEND), 1.0, 0.05, "downed crawl")
	player.is_downed = false
	player.is_crouching = false
	await _move(Vector3.ZERO, 5)
	assert_eq(_state(), "ground", "standing up again returns to the ground clips")


func test_teleport_is_not_read_as_running() -> void:
	player.global_position += Vector3(50.0, 0.0, 0.0)
	await wait_physics_frames(2)
	assert_almost_eq(animator.local_velocity.length(), 0.0, 0.01)


func test_look_pitch_bends_the_head_after_the_clip() -> void:
	await _move(Vector3.ZERO, 5)
	var skeleton: Skeleton3D = animator.aim.get_skeleton()
	var level: Vector3 = await _head_forward(skeleton)
	player.camera_rig.rotation.x = 0.5
	var looking: Vector3 = await _head_forward(skeleton)
	assert_almost_eq(level.angle_to(looking), 0.5, 0.05, "chest and head together turn by the full pitch")


func _head_forward(skeleton: Skeleton3D) -> Vector3:
	await skeleton.skeleton_updated
	await skeleton.skeleton_updated
	return skeleton.get_bone_global_pose(skeleton.find_bone("head")).basis.z


func test_headless_builds_no_tree() -> void:
	var other: Player = PLAYER.instantiate() as Player
	var headless: BodyAnimator = other.get_node("Body/BodyAnimator") as BodyAnimator
	headless.headless = true
	add_child_autofree(other)
	assert_null(headless.tree, "a dedicated server poses nothing")
	assert_false(headless.is_physics_processing())

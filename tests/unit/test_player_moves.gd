## Design move speeds, crouch toggle, slide from sprint and chained jump fall-off
## (docs/plans/core-loop-gaps.md, step 5).
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const STRIDE: SerumData = preload("res://content/serums/stride.tres")
const TICK: float = 1.0 / 60.0

var player: Player


func before_each() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = Layers.WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, 0)
	await wait_physics_frames(2)
	_run(0.3, 0)


func _frame(buttons: int, move: Vector2 = Vector2.ZERO) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.buttons = buttons
	frame.move = move
	return frame


func _run(seconds: float, buttons: int, move: Vector2 = Vector2.ZERO) -> void:
	for i: int in roundi(seconds / TICK):
		player.apply_frame(_frame(buttons, move), TICK)


func _flat_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func test_walk_sprint_and_crouch_top_speeds_match_the_design() -> void:
	_run(1.5, 0, Vector2(0, -1))
	assert_almost_eq(_flat_speed(), 4.5, 0.05, "walk")
	_run(1.5, InputFrame.SPRINT, Vector2(0, -1))
	assert_almost_eq(_flat_speed(), 6.8, 0.05, "sprint")
	_run(0.05, 0, Vector2(0, -1))
	_run(1.5, InputFrame.CROUCH, Vector2(0, -1))
	assert_almost_eq(_flat_speed(), 2.2, 0.05, "crouch walk")


func test_crouch_press_during_sprint_slides_3_5_to_5_metres_and_can_fire() -> void:
	_run(1.0, InputFrame.SPRINT, Vector2(0, -1))
	var start: Vector3 = player.global_position
	player.apply_frame(_frame(InputFrame.SPRINT | InputFrame.CROUCH, Vector2(0, -1)), TICK)
	assert_true(player.moves.is_sliding())
	assert_true(player.is_crouching)
	assert_false(player.is_sprinting, "a slide is not a sprint, so hip fire is allowed")
	_run(PlayerMoves.SLIDE_TIME - TICK, InputFrame.SPRINT | InputFrame.CROUCH, Vector2(1, 0))
	assert_false(player.moves.is_sliding())
	var travelled: float = Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	assert_between(travelled, 3.5, 5.0)
	assert_almost_eq(player.global_position.x, start.x, 0.2, "steering is locked")


func test_stride_slides_25_percent_longer() -> void:
	player.add_serum(STRIDE)
	_run(1.0, InputFrame.SPRINT, Vector2(0, -1))
	player.apply_frame(_frame(InputFrame.SPRINT | InputFrame.CROUCH, Vector2(0, -1)), TICK)
	_run(0.9, InputFrame.SPRINT | InputFrame.CROUCH, Vector2(0, -1))
	assert_true(player.moves.is_sliding(), "still sliding at 0.9 s")
	_run(0.15, InputFrame.SPRINT | InputFrame.CROUCH, Vector2(0, -1))
	assert_false(player.moves.is_sliding())


func test_releasing_crouch_ends_the_slide() -> void:
	_run(1.0, InputFrame.SPRINT, Vector2(0, -1))
	player.apply_frame(_frame(InputFrame.SPRINT | InputFrame.CROUCH, Vector2(0, -1)), TICK)
	player.apply_frame(_frame(InputFrame.SPRINT, Vector2(0, -1)), TICK)
	assert_false(player.moves.is_sliding())
	assert_false(player.is_crouching)


func test_holding_crouch_while_standing_still_does_not_slide() -> void:
	_run(0.5, InputFrame.CROUCH)
	assert_false(player.moves.is_sliding())
	assert_true(player.is_crouching)


func _peak_after_jump() -> float:
	var ground: float = player.global_position.y
	var peak: float = ground
	player.apply_frame(_frame(InputFrame.JUMP), TICK)
	for i: int in 120:
		player.apply_frame(_frame(0), TICK)
		peak = maxf(peak, player.global_position.y)
		if player.is_on_floor() and i > 5:
			break
	return peak - ground


func test_chained_jump_reaches_80_percent_and_resets_after_rest() -> void:
	var first: float = _peak_after_jump()
	var second: float = _peak_after_jump()
	assert_gt(first, 0.5)
	assert_almost_eq(second / first, 0.8, 0.05, "second jump within 0.4 s of landing")
	_run(0.45, 0)
	var rested: float = _peak_after_jump()
	assert_almost_eq(rested / first, 1.0, 0.05, "0.4 s on the floor resets the chain")


func _tap(action: StringName) -> InputFrame:
	var press: InputEventAction = InputEventAction.new()
	press.action = action
	press.pressed = true
	player.local_input._unhandled_input(press)
	return player.local_input.sample(0)


func test_crouch_key_toggles_and_a_sprint_press_stands_up() -> void:
	player.local_input.enabled = true
	assert_true((_tap(&"crouch")).has(InputFrame.CROUCH), "press crouches")
	assert_true(player.local_input.sample(0).has(InputFrame.CROUCH), "stays crouched after release")
	assert_false((_tap(&"crouch")).has(InputFrame.CROUCH), "second press stands up")
	_tap(&"crouch")
	assert_false((_tap(&"sprint")).has(InputFrame.CROUCH), "sprint press stands up")
	_tap(&"crouch")
	assert_false((_tap(&"jump")).has(InputFrame.CROUCH), "jump press stands up")

## PlayerMantle: mantle over waist- to chest-high ledges (docs/plans/mantle.md, step 1).
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const RULES: MantleRules = preload("res://content/feel/mantle_rules.tres")
const TICK: float = 1.0 / 60.0
const FORWARD: Vector2 = Vector2(0, -1)
## The ledge face is this far in front of the player's feet (player faces -Z).
const FACE_Z: float = -0.6

var player: Player


func before_each() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(40, 1, 40), Layers.WORLD)
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, 0)


func _box(centre: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = layer
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = centre
	return body


## A 3 m wide, 2 m deep ledge whose face is FACE_Z in front of the player.
func _ledge(height: float, layer: int = Layers.WORLD) -> void:
	_box(Vector3(0, height * 0.5, FACE_Z - 1.0), Vector3(3, height, 2), layer)


func _settle() -> void:
	await wait_physics_frames(2)
	_run(0.3, 0, Vector2.ZERO)


func _frame(buttons: int, move: Vector2) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.buttons = buttons
	frame.move = move
	return frame


func _run(seconds: float, buttons: int, move: Vector2) -> void:
	for i: int in roundi(seconds / TICK):
		player.apply_frame(_frame(buttons, move), TICK)


## Presses jump once while pushing forward, keeps pushing for `seconds`, then lets go
## and lets the player settle where they are.
func _jump_into(seconds: float = 0.6) -> void:
	player.apply_frame(_frame(InputFrame.JUMP, FORWARD), TICK)
	_run(seconds, 0, FORWARD)
	_run(0.4, 0, Vector2.ZERO)


func _assert_mantles(height: float) -> void:
	_ledge(height)
	await _settle()
	_jump_into()
	assert_almost_eq(player.global_position.y, height, 0.06, "stands on a %.1f m ledge" % height)
	assert_lt(player.global_position.z, FACE_Z, "moved onto the %.1f m ledge" % height)


func test_mantles_a_0_5_metre_ledge() -> void:
	await _assert_mantles(0.5)


func test_mantles_a_0_9_metre_ledge() -> void:
	await _assert_mantles(0.9)


func test_mantles_a_1_2_metre_ledge() -> void:
	await _assert_mantles(1.2)


func test_mantle_takes_the_rules_time() -> void:
	_ledge(1.0)
	await _settle()
	player.apply_frame(_frame(InputFrame.JUMP, FORWARD), TICK)
	assert_true(player.mantle.is_active(), "the press tick starts the mantle, not a jump")
	var ticks: int = 1
	while player.mantle.is_active() and ticks < 120:
		player.apply_frame(_frame(0, FORWARD), TICK)
		ticks += 1
	assert_almost_eq(ticks * TICK, RULES.duration(1.0), 3.0 * TICK)


func test_refuses_a_1_4_metre_ledge() -> void:
	_ledge(1.4)
	await _settle()
	_jump_into()
	assert_lt(player.global_position.y, 0.1, "too high: still on the floor")


func test_a_low_step_never_starts_a_mantle() -> void:
	_ledge(0.3)
	await _settle()
	player.apply_frame(_frame(InputFrame.JUMP, FORWARD), TICK)
	assert_false(player.mantle.is_active())


func test_no_forward_push_no_mantle() -> void:
	_ledge(1.0)
	await _settle()
	player.apply_frame(_frame(InputFrame.JUMP, Vector2.ZERO), TICK)
	assert_false(player.mantle.is_active())


func test_refuses_a_ledge_without_headroom() -> void:
	_ledge(1.2)
	_box(Vector3(0, 2.7 + 0.5, 0), Vector3(6, 1, 6), Layers.WORLD)
	await _settle()
	_jump_into()
	assert_lt(player.global_position.y, 0.1, "1.5 m of room above a 1.2 m ledge is too little")


func test_refuses_a_ledge_with_a_zombie_on_top() -> void:
	_ledge(1.0)
	_box(Vector3(0, 1.9, FACE_Z - 0.5), Vector3(0.8, 1.8, 0.8), Layers.ENEMY)
	await _settle()
	_jump_into()
	assert_lt(player.global_position.y, 0.1)


func test_a_barrier_blocker_counts_as_a_wall() -> void:
	_ledge(1.0)
	_box(Vector3(0, 1.3, FACE_Z + 0.05), Vector3(3, 2.6, 0.1), Layers.BARRIER)
	await _settle()
	_jump_into()
	assert_lt(player.global_position.z, 0.0 + 0.05, "not past the Blocker")
	assert_false(player.global_position.y > 0.9, "not on the ledge")


func test_pushing_forward_early_in_a_jump_still_mantles() -> void:
	_ledge(1.0)
	await _settle()
	player.apply_frame(_frame(InputFrame.JUMP, Vector2.ZERO), TICK)
	_run(0.15, 0, Vector2.ZERO)
	_run(0.5, 0, FORWARD)
	_run(0.4, 0, Vector2.ZERO)
	assert_almost_eq(player.global_position.y, 1.0, 0.06)


func test_pushing_forward_late_in_a_jump_does_not_mantle() -> void:
	_ledge(1.0)
	await _settle()
	player.apply_frame(_frame(InputFrame.JUMP, Vector2.ZERO), TICK)
	_run(0.5, 0, Vector2.ZERO)
	_run(0.3, 0, FORWARD)
	assert_false(player.mantle.is_active())
	assert_lt(player.global_position.y, 0.95, "fell short instead of climbing")


func test_jumping_first_does_not_raise_the_height_cap() -> void:
	_ledge(1.3)
	await _settle()
	player.apply_frame(_frame(InputFrame.JUMP, Vector2.ZERO), TICK)
	_run(0.2, 0, Vector2.ZERO)
	_run(1.0, 0, FORWARD)
	assert_lt(player.global_position.y, 0.5)


func test_no_shot_and_no_stamina_drain_while_mantling() -> void:
	var weapon: Weapon = player.weapons.give(Content.weapon(&"rifle_ar"))
	_ledge(1.2)
	await _settle()
	var sprint: float = player.sprint_left
	player.apply_frame(_frame(InputFrame.JUMP | InputFrame.FIRE | InputFrame.SPRINT, FORWARD), TICK)
	for i: int in 10:
		player.apply_frame(_frame(InputFrame.FIRE | InputFrame.SPRINT, FORWARD), TICK)
		assert_false(weapon.trigger_held, "trigger off while mantling")
	assert_true(player.mantle.is_active())
	assert_false(player.is_sprinting)
	assert_eq(player.sprint_left, sprint)


func test_a_crouch_press_mid_mantle_starts_no_slide() -> void:
	_ledge(1.0)
	await _settle()
	player.apply_frame(_frame(InputFrame.JUMP | InputFrame.SPRINT, FORWARD), TICK)
	player.apply_frame(_frame(InputFrame.SPRINT | InputFrame.CROUCH, FORWARD), TICK)
	assert_true(player.mantle.is_active())
	assert_false(player.moves.is_sliding())


func test_a_teleport_cancels_the_mantle() -> void:
	_ledge(1.0)
	await _settle()
	player.apply_frame(_frame(InputFrame.JUMP, FORWARD), TICK)
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(5, 0.05, 5)))
	assert_false(player.mantle.is_active())
	player.apply_frame(_frame(0, Vector2.ZERO), TICK)
	assert_almost_eq(player.global_position.x, 5.0, 0.01)


func test_a_mantle_dips_the_camera_and_plays_the_sound() -> void:
	_ledge(1.0)
	await _settle()
	player.camera_rig.head_bob = 0.6
	var sound: AudioStreamPlayer = player.get_node(^"MantleSound") as AudioStreamPlayer
	player.apply_frame(_frame(InputFrame.JUMP, FORWARD), TICK)
	assert_true(sound.playing, "mantle sound")
	var deepest: float = 0.0
	for i: int in 30:
		player.apply_frame(_frame(0, FORWARD), TICK)
		deepest = minf(deepest, player.camera.position.y)
	assert_lt(deepest, -0.04, "camera dipped")
	assert_almost_eq(player.camera.position.y, 0.0, 0.02, "and came back")


func test_no_dip_with_head_bob_off() -> void:
	_ledge(1.0)
	await _settle()
	player.camera_rig.head_bob = 0.0
	player.apply_frame(_frame(InputFrame.JUMP, FORWARD), TICK)
	for i: int in 30:
		player.apply_frame(_frame(0, FORWARD), TICK)
		assert_almost_eq(player.camera.position.y, 0.0, 0.001, "no camera offset at head bob 0")


func test_going_down_cancels_the_mantle() -> void:
	_ledge(1.0)
	await _settle()
	player.apply_frame(_frame(InputFrame.JUMP, FORWARD), TICK)
	assert_true(player.mantle.is_active())
	player.is_downed = true
	player.apply_frame(_frame(0, FORWARD), TICK)
	assert_false(player.mantle.is_active())

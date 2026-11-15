## Co-op downed controls retain crawl and sidearm fire, while dead players stay still.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")


func after_each() -> void:
	for action: StringName in [&"move_forward", &"sprint", &"fire"]:
		Input.action_release(action)
	Net.leave()


func test_downed_controls_and_dead_movement() -> void:
	assert_eq(Net.host(24647), OK)
	var player: Player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.weapons.give(Content.weapon(&"pistol_service"))
	player.weapons.give(Content.weapon(&"rifle_ar"))
	player.take_damage(DamageInfo.create(1000.0, null))
	for action: StringName in [&"move_forward", &"sprint", &"fire"]:
		Input.action_press(action)
	var cycle: InputEventAction = InputEventAction.new()
	cycle.action = &"weapon_next"
	cycle.pressed = true
	player.local_input._unhandled_input(cycle)
	player._read_input(player.local_input.sample(0))
	assert_true(player.input_enabled, "downed players retain crawl and fire input")
	assert_true(player.is_crouching)
	assert_false(player.is_sprinting)
	assert_eq(player.weapons.current.data.id, &"pistol_service", "cycling cannot select the rifle")
	assert_true(player.weapons.current.trigger_held)
	player._move(1.0, player.local_input.sample(0))
	assert_lte(Vector2(player.velocity.x, player.velocity.z).length(), player.walk_speed * 0.21)
	player.state_sync._physics_process(30.0)
	assert_true(player.is_dead)
	var dead_position: Vector3 = player.position
	player.apply_frame(player.local_input.sample(1), 1.0)
	assert_eq(player.position, dead_position)
	assert_false(player.visible)

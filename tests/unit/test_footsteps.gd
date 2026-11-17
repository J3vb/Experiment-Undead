## Footsteps: step rate per move state, landing thud by fall speed, metal floors.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const RUST: Material = preload("res://levels/materials/rust.tres")
const WOOD: Material = preload("res://levels/materials/wood.tres")

var player: Player
var steps: Footsteps


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	steps = player.get_node("Footsteps") as Footsteps
	steps.set_physics_process(false)


func _count_steps(seconds: float, speed: float, sprinting: bool, crouching: bool) -> int:
	var count: int = 0
	for i: int in roundi(seconds * 60.0):
		if steps.advance(1.0 / 60.0, speed, true, sprinting, crouching):
			count += 1
	return count


func test_walk_steps_every_half_second() -> void:
	assert_eq(_count_steps(3.0, 5.0, false, false), 6)


func test_sprint_steps_faster_than_walk() -> void:
	assert_eq(_count_steps(3.4, 7.6, true, false), 10)


func test_crouch_steps_slower_than_walk() -> void:
	assert_eq(_count_steps(2.8, 2.75, false, true), 4)


func test_no_steps_standing_or_in_the_air() -> void:
	assert_eq(_count_steps(2.0, 0.5, false, false), 0, "too slow")
	for i: int in 120:
		assert_false(steps.advance(1.0 / 60.0, 5.0, false, false, false), "airborne")


func test_first_step_comes_soon_after_starting() -> void:
	_count_steps(1.0, 0.0, false, false)
	assert_true(_count_steps(0.2, 5.0, false, false) >= 1)


func test_landing_thud_scales_with_fall_speed() -> void:
	assert_eq(steps.landing_volume_db(2.0), -INF, "small hop is silent")
	var soft: float = steps.landing_volume_db(4.8)
	var hard: float = steps.landing_volume_db(9.0)
	assert_gt(hard, soft)
	assert_eq(steps.landing_volume_db(30.0), 0.0, "capped at full volume")


func test_metal_floor_materials() -> void:
	var block: Block = Block.new()
	block.material = RUST
	assert_true(steps.is_metal(block))
	block.material = WOOD
	assert_false(steps.is_metal(block))
	assert_false(steps.is_metal(null))
	block.free()


func test_steps_use_player_bus() -> void:
	for player_name: String in ["Concrete", "Metal", "Land"]:
		var sound: AudioStreamPlayer = steps.get_node(player_name) as AudioStreamPlayer
		assert_eq(sound.bus, &"Player")
		assert_not_null(sound.stream)
		assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(sound.bus)), &"SFX")

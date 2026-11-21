## Sprint stamina: 4 s of sprint, then 3 s without; Stride doubles the sprint.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)


func _sprint_for(seconds: float) -> void:
	player.is_sprinting = true
	for i: int in roundi(seconds * 10.0):
		player.moves.tick_stamina(player, 0.1)


func test_sprint_runs_out_after_4_seconds() -> void:
	_sprint_for(3.9)
	assert_true(player.moves.can_sprint())
	_sprint_for(0.2)
	assert_false(player.moves.can_sprint(), "out of breath")


func test_cooldown_blocks_for_3_seconds_then_refills() -> void:
	player.is_sprinting = true
	player.moves.tick_stamina(player, 4.5)
	player.is_sprinting = false
	player.moves.tick_stamina(player, 2.9)
	assert_false(player.moves.can_sprint())
	player.moves.tick_stamina(player, 0.2)
	assert_true(player.moves.can_sprint())
	assert_eq(player.sprint_left, 4.0, "full again")


func test_stopping_early_refills_over_time() -> void:
	_sprint_for(2.0)
	player.is_sprinting = false
	player.moves.tick_stamina(player, 1.5)
	assert_almost_eq(player.sprint_left, 4.0, 0.01)


func test_stride_doubles_sprint_time() -> void:
	player.add_serum(load("res://content/serums/stride.tres") as SerumData)
	player.moves.tick_stamina(player, 10.0)
	_sprint_for(7.9)
	assert_true(player.moves.can_sprint())
	_sprint_for(0.2)
	assert_false(player.moves.can_sprint())

## The level-up ring and sting play for the local player only.
extends GutTest

const BURST: PackedScene = preload("res://systems/ui/level_up_burst.tscn")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var burst: LevelUpBurst


func before_each() -> void:
	burst = BURST.instantiate() as LevelUpBurst
	add_child_autofree(burst)


func _player(authority: int) -> Player:
	var player: Player = PLAYER.instantiate() as Player
	player.set_multiplayer_authority(authority)
	add_child_autofree(player)
	player.set_physics_process(false)
	return player


func test_local_level_up_plays_the_ring_and_sting() -> void:
	assert_false(burst.is_playing())
	Events.player_leveled_up.emit(_player(1), 2)
	assert_true(burst.is_playing(), "ring is growing")
	assert_true(burst.sting.playing, "sting plays")
	assert_eq(burst.sting.bus, &"UI")
	await wait_seconds(LevelUpBurst.DURATION + 0.1)
	assert_false(burst.is_playing(), "ring is gone after its time")


func test_a_teammates_level_up_plays_nothing() -> void:
	Events.player_leveled_up.emit(_player(2), 5)
	assert_false(burst.is_playing())
	assert_false(burst.sting.playing)

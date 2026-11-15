## Player.get_stat() multiplies the multipliers of every active Serum.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")


func _serum(stat: StringName, value: float) -> SerumData:
	var serum: SerumData = SerumData.new()
	serum.multipliers[stat] = value
	return serum


func test_stats_stack_by_multiplying() -> void:
	var player: Player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	assert_eq(player.get_stat(&"reload_time"), 1.0, "no serums = 1")
	player.add_serum(_serum(&"reload_time", 0.5))
	player.add_serum(_serum(&"reload_time", 0.5))
	player.add_serum(_serum(&"ads_time", 0.8))
	assert_almost_eq(player.get_stat(&"reload_time"), 0.25, 0.0001)
	assert_almost_eq(player.get_stat(&"ads_time"), 0.8, 0.0001)


func test_same_serum_twice_counts_once() -> void:
	var player: Player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	var serum: SerumData = _serum(&"fire_interval", 0.5)
	player.add_serum(serum)
	player.add_serum(serum)
	assert_eq(player.serums.size(), 1)
	assert_almost_eq(player.get_stat(&"fire_interval"), 0.5, 0.0001)

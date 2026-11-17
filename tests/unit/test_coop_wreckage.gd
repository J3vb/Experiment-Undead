## The truck-gap wreckage shows below 3 players and hides from 3, following
## the live player count both ways.
extends GutTest


func _player() -> Node3D:
	var player: Node3D = Node3D.new()
	player.add_to_group(&"players")
	add_child_autofree(player)
	return player


func test_wreckage_follows_the_player_count() -> void:
	var wreckage: CoopWreckage = CoopWreckage.new()
	add_child_autofree(wreckage)
	var players: Array[Node3D] = [_player(), _player()]
	for player: Node3D in players:
		wreckage._watch(player)
	assert_true(wreckage.visible, "2 players: burning")
	var third: Node3D = _player()
	wreckage._watch(third)
	assert_false(wreckage.visible, "3 players: burned out")
	third.free()
	assert_true(wreckage.visible, "a player left: burning again")

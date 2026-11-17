## The vent climb step is there (with collision) only with 3 or more players.
extends GutTest


func _player() -> Node3D:
	var player: Node3D = Node3D.new()
	player.add_to_group(&"players")
	add_child_autofree(player)
	return player


func test_step_follows_the_player_count() -> void:
	var step: VentStep = VentStep.new()
	var body: StaticBody3D = StaticBody3D.new()
	step.add_child(body)
	add_child_autofree(step)
	for player: Node3D in [_player(), _player()]:
		step._watch(player)
	assert_false(step.visible, "2 players: one-way drop")
	assert_eq(body.collision_layer, 0, "no collision")
	var third: Node3D = _player()
	step._watch(third)
	assert_true(step.visible, "3 players: the step is there")
	assert_eq(body.collision_layer, Layers.WORLD, "players can stand on it")
	third.free()
	assert_eq(body.collision_layer, 0, "a player left: gone again")

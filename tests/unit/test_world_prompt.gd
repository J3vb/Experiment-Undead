## WorldPrompt brackets the focused Interactable on screen and moves the prompt box beside it,
## or puts the box at its fixed spot when there is nothing to bracket.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player
var prompt: WorldPrompt
var box: PanelContainer


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.camera.current = true
	prompt = WorldPrompt.new()
	add_child_autofree(prompt)
	prompt.size = prompt.get_viewport_rect().size
	box = PanelContainer.new()
	box.size = Vector2(240.0, 48.0)
	add_child_autofree(box)
	prompt.box = box
	Events.player_spawned.emit(player)


func _medkit(distance: float) -> Interactable:
	var target: Interactable = Interactable.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cube: BoxShape3D = BoxShape3D.new()
	cube.size = Vector3(0.4, 0.2, 0.2)
	shape.shape = cube
	target.add_child(shape)
	add_child_autofree(target)
	target.global_position = player.camera.global_position - player.camera.global_basis.z * distance
	return target


func test_screen_rect_is_empty_behind_the_camera() -> void:
	var behind: Vector3 = player.camera.global_position + player.camera.global_basis.z * 2.0
	var rect: Rect2 = WorldPrompt.screen_rect(player.camera, PackedVector3Array([behind]))
	assert_false(rect.has_area())
	assert_false(WorldPrompt.screen_rect(player.camera, PackedVector3Array()).has_area())


func test_box_sits_up_right_of_the_brackets_and_on_screen() -> void:
	var screen: Vector2 = Vector2(1920.0, 1080.0)
	var spot: Vector2 = WorldPrompt.box_position(Rect2(900, 500, 100, 60), Vector2(240, 48), screen)
	assert_eq(spot, Vector2(1040.0, 428.0))
	var edge: Vector2 = WorldPrompt.box_position(Rect2(1800, 10, 100, 60), Vector2(240, 48), screen)
	assert_eq(edge, Vector2(screen.x - 240.0 - WorldPrompt.MARGIN, WorldPrompt.MARGIN))


func test_focus_in_front_gets_brackets_and_moves_the_box() -> void:
	player.focus = _medkit(1.5)
	box.visible = true
	prompt._process(0.0)
	assert_true(prompt.brackets.has_area(), "a small object in view is bracketed")
	var centre: Vector2 = prompt.get_viewport_rect().size * 0.5
	assert_true(prompt.brackets.grow(2.0).has_point(centre), "the object sits under the crosshair")
	assert_gt(box.position.x, prompt.brackets.end.x)


func test_no_focus_uses_the_fixed_spot() -> void:
	player.focus = null
	box.visible = true
	prompt._process(0.0)
	assert_false(prompt.brackets.has_area())
	var screen: Vector2 = prompt.get_viewport_rect().size
	assert_almost_eq(box.position.y, screen.y * 0.5 + WorldPrompt.FIXED_DROP, 0.01)


func test_huge_focus_falls_back_to_the_fixed_spot() -> void:
	player.focus = _medkit(0.05)
	box.visible = true
	prompt._process(0.0)
	assert_false(prompt.brackets.has_area(), "an object filling the screen gets no brackets")


func test_hidden_box_draws_nothing() -> void:
	player.focus = _medkit(1.5)
	box.visible = false
	prompt._process(0.0)
	assert_false(prompt.brackets.has_area())

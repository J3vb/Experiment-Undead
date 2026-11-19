## PlayerInteract uses a target once per press, or on a timer while held for targets
## that repeat (barrier repair).
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const TICK: float = 1.0 / 60.0


class Target:
	extends Interactable
	var uses: int = 0
	var interval: float = 0.0

	func hold_interval() -> float:
		return interval

	func interact(_player: Player, _facts: Dictionary = {}) -> void:
		uses += 1


var player: Player
var target: Target


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.position = Vector3(100, 100, 100)
	target = Target.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	target.add_child(shape)
	add_child_autofree(target)
	target.global_position = player.camera.global_position + Vector3(0, 0, -1.5)
	await wait_physics_frames(2)


func _frame(buttons: int) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.buttons = buttons
	return frame


## Presses interact, then keeps it held for `ticks` more ticks.
func _press_and_hold(ticks: int) -> void:
	player.interaction.update(player, _frame(InputFrame.INTERACT | InputFrame.INTERACT_HELD), TICK)
	for i: int in ticks:
		player.interaction.update(player, _frame(InputFrame.INTERACT_HELD), TICK)


func test_focus_finds_the_target() -> void:
	player.interaction.update(player, _frame(0), TICK)
	assert_eq(player.focus, target)
	assert_eq(target.uses, 0, "looking does not use it")


func test_holding_uses_a_press_only_target_once() -> void:
	_press_and_hold(120)
	assert_eq(target.uses, 1, "a wall-buy or door is one use per press")


func test_holding_repeats_on_the_target_interval() -> void:
	target.interval = 0.6
	_press_and_hold(120)
	assert_eq(target.uses, 4, "uses at 0, 0.6, 1.2 and 1.8 s")


func test_letting_go_stops_the_repeats() -> void:
	target.interval = 0.6
	_press_and_hold(10)
	for i: int in 120:
		player.interaction.update(player, _frame(0), TICK)
	assert_eq(target.uses, 1)


func test_downed_players_cannot_interact() -> void:
	player.is_downed = true
	_press_and_hold(60)
	assert_eq(target.uses, 0)

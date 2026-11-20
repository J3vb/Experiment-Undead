## Mantle in Halcyon Labs (docs/plans/mantle.md, step 1): a mess table (0.9 m)
## can be climbed, but the 1.4 m vent ledge sill keeps the vent drop one-way
## while the co-op VentStep ramp is off.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const TICK: float = 1.0 / 60.0

var session: GameSession
var player: Player


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	session.rng_seed = 99
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	player = session.get_players()[0]
	player.set_physics_process(false)


func after_each() -> void:
	get_tree().paused = false


func _frame(buttons: int, move: Vector2) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.buttons = buttons
	frame.move = move
	return frame


## Stands at `at` facing `yaw`, settles, then presses jump while pushing forward.
func _mantle_from(at: Vector3, yaw: float) -> void:
	player.teleport(Transform3D(Basis(Vector3.UP, yaw), at))
	await wait_physics_frames(2)
	for i: int in 20:
		player.apply_frame(_frame(0, Vector2.ZERO), TICK)
	player.apply_frame(_frame(InputFrame.JUMP, Vector2(0, -1)), TICK)
	for i: int in 30:
		player.apply_frame(_frame(0, Vector2(0, -1)), TICK)
	for i: int in 20:
		player.apply_frame(_frame(0, Vector2.ZERO), TICK)


func test_a_mess_table_can_be_mantled() -> void:
	await _mantle_from(Vector3(48, 0.05, 37.2), 0.0)
	assert_almost_eq(player.global_position.y, 0.9, 0.1, "on top of mess_table_north")


func test_the_vent_ledge_stays_one_way_below_three_players() -> void:
	assert_lt(get_tree().get_nodes_in_group(&"players").size(), VentStep.COOP_PLAYERS, "ramp is off")
	await _mantle_from(Vector3(57.4, 0.05, 45), -PI / 2.0)
	assert_lt(player.global_position.y, 0.2, "still on the Mess Hall floor")
	assert_lt(player.global_position.x, 58.0, "not into the vent")

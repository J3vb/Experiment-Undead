## CompassStrip turns the local look direction into a heading (north = -Z) and places letters.
extends GutTest

var compass: CompassStrip


func before_each() -> void:
	compass = CompassStrip.new()
	compass.size = Vector2(560.0, 44.0)
	add_child_autofree(compass)


func test_heading_for_look_directions() -> void:
	assert_almost_eq(CompassStrip.heading_for(Vector3.FORWARD), 0.0, 0.001)
	assert_almost_eq(CompassStrip.heading_for(Vector3.RIGHT), 90.0, 0.001)
	assert_almost_eq(CompassStrip.heading_for(Vector3.BACK), 180.0, 0.001)
	assert_almost_eq(CompassStrip.heading_for(Vector3.LEFT), 270.0, 0.001)


func test_turning_right_by_ninety_faces_east() -> void:
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(-90.0))
	assert_almost_eq(CompassStrip.heading_for(-basis.z), 90.0, 0.001)


func test_north_is_centred_at_heading_zero() -> void:
	compass.heading = 0.0
	assert_almost_eq(compass.bearing_x(0.0), 280.0, 0.001)
	assert_true(is_nan(compass.bearing_x(180.0)), "south is behind you")


func test_east_centred_when_facing_east() -> void:
	compass.heading = 90.0
	assert_almost_eq(compass.bearing_x(90.0), 280.0, 0.001)
	assert_lt(compass.bearing_x(45.0), 280.0, "north-east is to the left")


func test_bearings_wrap_at_360() -> void:
	compass.heading = 350.0
	assert_almost_eq(compass.bearing_x(0.0), 280.0 + 10.0 * 560.0 / CompassStrip.WINDOW, 0.001)
	assert_almost_eq(compass.bearing_x(315.0), 280.0 - 35.0 * 560.0 / CompassStrip.WINDOW, 0.001)


func test_draws_without_a_player() -> void:
	compass.visible = true
	compass._process(0.0)
	compass.queue_redraw()
	await wait_process_frames(1)
	assert_null(compass.player)


func test_hidden_until_a_round_like_the_round_counter() -> void:
	assert_false(compass.visible)
	Events.intermission_started.emit(1, 10.0)
	assert_false(compass.visible, "the break before round 1 keeps it hidden")
	Events.round_started.emit(1, 6)
	assert_true(compass.visible)


func test_late_joiner_in_a_break_sees_it() -> void:
	Events.intermission_started.emit(5, 10.0)
	assert_true(compass.visible)

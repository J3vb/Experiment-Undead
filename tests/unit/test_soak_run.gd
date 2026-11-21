## Checks soak argument validation and the fight bot's aim maths without starting real waves.
extends GutTest

const SOAK_RUN: GDScript = preload("res://tools/soak/soak_run.gd")
const SOAK_BOT: GDScript = preload("res://tools/soak/soak_bot.gd")

var runner: Node


func before_each() -> void:
	runner = SOAK_RUN.new()
	autofree(runner)


func test_rounds_argument_requires_a_positive_integer() -> void:
	assert_true(runner._parse_argument("--rounds", "3"))
	assert_eq(runner._rounds, 3)
	for value: String in ["0", "-1", "1.5", "nope"]:
		assert_false(runner._parse_argument("--rounds", value), value)
		assert_eq(runner._rounds, 3)


func test_seed_argument_accepts_zero_and_negative_integers() -> void:
	assert_true(runner._parse_argument("--seed", "0"))
	assert_eq(runner._seed, 0)
	assert_true(runner._parse_argument("--seed", "-23"))
	assert_eq(runner._seed, -23)
	assert_false(runner._parse_argument("--seed", "1.5"))
	assert_eq(runner._seed, -23)


func test_timescale_argument_requires_a_positive_finite_number() -> void:
	assert_true(runner._parse_argument("--timescale", "0.5"))
	assert_eq(runner._timescale, 0.5)
	for value: String in ["0", "-2", "1e999", "nope"]:
		assert_false(runner._parse_argument("--timescale", value), value)
		assert_eq(runner._timescale, 0.5)
	assert_engine_error("Exponent too high")


func test_unknown_argument_preserves_settings() -> void:
	assert_false(runner._parse_argument("--unknown", "12"))
	assert_eq(runner._rounds, 10)
	assert_eq(runner._seed, 1)
	assert_eq(runner._timescale, 4.0)


func test_fight_and_wall_arguments() -> void:
	assert_true(runner._parse_argument("--fight", "1"))
	assert_true(runner._fight)
	assert_true(runner._parse_argument("--fight", "0"))
	assert_false(runner._fight)
	assert_false(runner._parse_argument("--fight", "yes"))
	assert_true(runner._parse_argument("--wall", "some_gun"))
	assert_eq(runner._wall, &"some_gun")


func test_bot_turns_the_short_way_and_caps_the_turn() -> void:
	var right: Vector3 = Vector3(1.0, 0.0, 0.0)
	var turn: Vector2 = SOAK_BOT.turn_toward(Vector3.FORWARD, right, 10.0)
	assert_almost_eq(turn.x, PI / 2.0, 0.001, "positive look.x turns right")
	assert_almost_eq(turn.y, 0.0, 0.001)
	assert_almost_eq(SOAK_BOT.turn_toward(Vector3.FORWARD, right, 0.1).length(), 0.1, 0.001)
	var up: Vector3 = Vector3(0.0, 1.0, -1.0).normalized()
	assert_lt(SOAK_BOT.turn_toward(Vector3.FORWARD, up, 10.0).y, 0.0, "negative look.y pitches up")


func test_bot_uses_its_field_ability_when_ready_and_a_zombie_is_close() -> void:
	assert_true(SOAK_BOT.wants_ability(true, 4.0, 6.0))
	assert_false(SOAK_BOT.wants_ability(false, 4.0, 6.0), "still cooling down")
	assert_false(SOAK_BOT.wants_ability(true, 9.0, 6.0), "nothing close")

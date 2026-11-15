## Checks soak argument validation without starting real waves.
extends GutTest

const SOAK_RUN: GDScript = preload("res://tools/soak/soak_run.gd")

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

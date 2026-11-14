## Checks benchmark argument assignment without starting a session or collecting timings.
extends GutTest

const BENCHMARK: GDScript = preload("res://tools/benchmark/benchmark_run.gd")

var runner: Node


func before_each() -> void:
	runner = BENCHMARK.new()
	autofree(runner)


func test_zombie_argument_sets_population() -> void:
	assert_true(runner._parse_argument("--zombies", "48"))
	assert_eq(runner._zombies, 48)


func test_seconds_argument_accepts_fractional_duration() -> void:
	assert_true(runner._parse_argument("--seconds", "0.2"))
	assert_eq(runner._seconds, 0.2)
	assert_true(runner._parse_argument("--seconds", "1e2"))
	assert_eq(runner._seconds, 100.0)


func test_seed_argument_accepts_zero_and_negative_integers() -> void:
	assert_true(runner._parse_argument("--seed", "0"))
	assert_eq(runner._seed, 0)
	assert_true(runner._parse_argument("--seed", "-23"))
	assert_eq(runner._seed, -23)

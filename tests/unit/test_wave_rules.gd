extends GutTest

var rules: WaveRules


func before_each() -> void:
	rules = WaveRules.new()
	rules.base_count = 6
	rules.count_linear = 3.0
	rules.count_quadratic = 0.5
	rules.extra_per_player = 4


func test_count_grows_each_round() -> void:
	assert_eq(rules.get_enemy_count(1), 6)
	assert_eq(rules.get_enemy_count(2), 10)  # 6 + 3 + 0.5 -> round(3.5) = 4
	var last: int = 0
	for r: int in range(1, 30):
		var c: int = rules.get_enemy_count(r)
		assert_gt(c, last, "round %d bigger than round %d" % [r, r - 1])
		last = c


func test_extra_players_add_enemies() -> void:
	assert_eq(rules.get_enemy_count(1, 3) - rules.get_enemy_count(1, 1), 8)


func test_speed_is_capped() -> void:
	rules.speed_growth_per_round = 0.5
	rules.max_speed_multiplier = 1.8
	assert_almost_eq(rules.get_speed_multiplier(50), 1.8, 0.001)


func test_spawn_interval_has_floor() -> void:
	assert_almost_eq(rules.get_spawn_interval(100), rules.spawn_interval_min, 0.001)


func test_enemy_mix_respects_first_round() -> void:
	var walker: EnemyData = EnemyData.new()
	var runner: EnemyData = EnemyData.new()
	var a: EnemySpawnEntry = EnemySpawnEntry.new()
	a.enemy = walker
	var b: EnemySpawnEntry = EnemySpawnEntry.new()
	b.enemy = runner
	b.weight = 100.0
	b.first_round = 5
	rules.enemy_mix = [a, b]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	for i: int in 50:
		assert_eq(rules.pick_enemy(1, rng), walker)
	var saw_runner: bool = false
	for i: int in 50:
		if rules.pick_enemy(5, rng) == runner:
			saw_runner = true
	assert_true(saw_runner)

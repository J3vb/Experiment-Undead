extends GutTest

const DEFAULT_RULES: WaveRules = preload("res://content/waves/default_waves.tres")

var rules: WaveRules


func before_each() -> void:
	rules = DEFAULT_RULES


func test_counts_follow_the_design() -> void:
	var expected: Dictionary = {1: 6, 2: 8, 3: 13, 4: 18, 5: 20, 6: 21, 10: 30, 20: 63, 30: 114}
	for r: int in expected:
		assert_eq(rules.get_enemy_count(r), expected[r], "round %d count" % r)


func test_rounds_match_the_balance_sheet() -> void:
	var file: FileAccess = FileAccess.open("res://docs/design/balance/rounds.csv", FileAccess.READ)
	assert_not_null(file, "rounds.csv readable")
	if file == null:
		return
	var checked: int = 0
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 4 or not row[0].is_valid_int() or int(row[0]) > 30:
			continue
		var r: int = int(row[0])
		assert_eq(rules.get_enemy_count(r), int(row[1]), "round %d count" % r)
		assert_almost_eq(rules.get_round_health(r), float(row[2]), 0.01, "round %d health" % r)
		assert_almost_eq(rules.get_spawn_interval(r), float(row[3]), 0.001, "round %d spawn delay" % r)
		checked += 1
	assert_eq(checked, 30, "rounds 1-30 checked")


func test_counts_grow_each_round() -> void:
	var last: int = 0
	for r: int in range(1, 51):
		var c: int = rules.get_enemy_count(r)
		assert_gt(c, last, "round %d bigger than round %d" % [r, r - 1])
		last = c


func test_coop_scales_count_and_alive_cap() -> void:
	assert_eq(rules.get_enemy_count(10, 2), 45)
	assert_eq(rules.get_enemy_count(10, 4), 75)
	assert_eq(rules.get_max_alive(1), 24)
	assert_eq(rules.get_max_alive(2), 30)
	assert_eq(rules.get_max_alive(4), 42)


func test_health_adds_then_multiplies() -> void:
	assert_almost_eq(rules.get_round_health(1), 120.0, 0.01)
	assert_almost_eq(rules.get_round_health(9), 840.0, 0.01)
	assert_almost_eq(rules.get_round_health(10), 915.6, 0.01)
	assert_almost_eq(rules.get_round_health(11), 998.004, 0.01)
	assert_almost_eq(rules.get_health_multiplier(1), 1.0, 0.0001)
	assert_almost_eq(rules.get_health_multiplier(9), 7.0, 0.0001)
	assert_almost_eq(rules.get_health_multiplier(10), 7.63, 0.0001)


func test_spawn_delay_shrinks_with_floor() -> void:
	assert_almost_eq(rules.get_spawn_interval(1), 2.0, 0.001)
	assert_almost_eq(rules.get_spawn_interval(10), 1.26, 0.001)
	assert_almost_eq(rules.get_spawn_interval(100), 0.3, 0.001)


func test_damage_does_not_grow() -> void:
	assert_almost_eq(rules.get_damage_multiplier(30), 1.0, 0.0001)


func test_speed_mix_by_round() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var counts: Dictionary = {}
	for i: int in 2000:
		var speed: float = rules.roll_speed(20, rng)
		counts[speed] = counts.get(speed, 0) + 1
		assert_eq(rules.roll_speed(1, rng), 1.2, "rounds 1-3 only shamble")
	assert_false(counts.has(1.2), "no shamblers from round 20")
	assert_almost_eq(float(counts.get(2.6, 0)) / 2000.0, 0.1, 0.03)
	assert_almost_eq(float(counts.get(4.2, 0)) / 2000.0, 0.6, 0.04)
	assert_almost_eq(float(counts.get(5.6, 0)) / 2000.0, 0.3, 0.04)


func test_speed_bands_switch_at_their_first_round() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var seen_jog: bool = false
	for i: int in 200:
		assert_true(rules.roll_speed(3, rng) == 1.2, "round 3 still all shamble")
		seen_jog = seen_jog or rules.roll_speed(4, rng) == 2.6
	assert_true(seen_jog, "round 4 has joggers")


func test_enemy_mix_respects_first_round() -> void:
	var custom: WaveRules = WaveRules.new()
	var walker: EnemyData = EnemyData.new()
	var bloater: EnemyData = EnemyData.new()
	var a: EnemySpawnEntry = EnemySpawnEntry.new()
	a.enemy = walker
	var b: EnemySpawnEntry = EnemySpawnEntry.new()
	b.enemy = bloater
	b.weight = 100.0
	b.first_round = 5
	custom.enemy_mix = [a, b]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	for i: int in 50:
		assert_eq(custom.pick_enemy(1, rng), walker)
	var saw_bloater: bool = false
	for i: int in 50:
		if custom.pick_enemy(5, rng) == bloater:
			saw_bloater = true
	assert_true(saw_bloater)


func test_blackout_schedule_starts_at_round_6_with_gaps_of_5_to_7() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var rounds: PackedInt32Array = rules.roll_blackouts(rng, 50)
	assert_eq(rounds[0], 6, "first Blackout is round 6")
	assert_gt(rounds.size(), 5, "several Blackouts by round 50")
	for i: int in range(1, rounds.size()):
		assert_between(rounds[i] - rounds[i - 1], 5, 7, "gap before Blackout %d" % rounds[i])
	assert_lte(rounds[rounds.size() - 1], 50)


func test_blackout_count_is_one_and_a_half_times_the_round() -> void:
	for r: int in [6, 11, 20]:
		assert_eq(rules.get_blackout_count(r), floori(rules.get_enemy_count(r) * 1.5), "round %d" % r)
	assert_eq(rules.get_blackout_count(6), 31, "21 x 1.5")
	assert_eq(rules.get_blackout_count(6, 2), floori(rules.get_enemy_count(6, 2) * 1.5), "co-op count scales too")


func test_no_blackout_enemy_means_no_blackouts() -> void:
	var plain: WaveRules = WaveRules.new()
	assert_eq(plain.roll_blackouts(RandomNumberGenerator.new(), 50).size(), 0)

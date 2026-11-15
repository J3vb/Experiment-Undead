## StatBlock combines runtime modifiers without changing content or other sources.
extends GutTest


func test_increased_modifiers_add_in_one_bucket() -> void:
	var stats: StatBlock = StatBlock.new()
	stats.add_modifier(&"damage", "increased", 0.1, &"gun")
	stats.add_modifier(&"damage", "increased", 0.2, &"gear")
	stats.add_modifier(&"other", "increased", 5.0, &"gear")
	var modifier: Modifier = stats.modifiers[0]
	assert_eq(modifier.stat, &"damage")
	assert_eq(modifier.op, "increased")
	assert_eq(modifier.value, 0.1)
	assert_eq(modifier.source, &"gun")
	assert_almost_eq(stats.value(&"damage", 100.0), 130.0, 0.0001)
	assert_eq(stats.value(&"unknown", 25.0), 25.0)


func test_more_modifiers_multiply_after_increased_and_before_flat() -> void:
	var stats: StatBlock = StatBlock.new()
	stats.add_modifier(&"health", "increased", 0.5, &"vest")
	stats.add_modifier(&"health", "more", 2.0, &"serum")
	stats.add_modifier(&"health", "more", 1.5, &"power_up")
	stats.add_modifier(&"health", "flat", 20.0, &"charm")
	assert_almost_eq(stats.value(&"health", 100.0), 470.0, 0.0001)


func test_increased_modifiers_add_across_gear_and_gun_blocks() -> void:
	var gear: StatBlock = StatBlock.new()
	var gun: StatBlock = StatBlock.new()
	gear.add_modifier(&"damage", "increased", 0.1, &"charm")
	gun.add_modifier(&"damage", "increased", 0.2, &"gun")
	assert_almost_eq(gun.value(&"damage", 100.0, gear), 130.0, 0.0001)
	assert_almost_eq(gun.value(&"damage", 100.0), 120.0, 0.0001)
	assert_almost_eq(gear.value(&"damage", 100.0), 110.0, 0.0001)


func test_combined_blocks_multiply_more_and_add_flat_afterwards() -> void:
	var gear: StatBlock = StatBlock.new()
	var gun: StatBlock = StatBlock.new()
	gear.add_modifier(&"damage", "more", 1.5, &"charm")
	gear.add_modifier(&"damage", "flat", 10.0, &"charm")
	gun.add_modifier(&"damage", "more", 2.0, &"gun")
	gun.add_modifier(&"damage", "flat", 20.0, &"gun")
	assert_eq(gun.value(&"damage", 100.0, gear), 330.0)


func test_combined_fire_rate_increased_bucket_is_capped_once() -> void:
	var gear: StatBlock = StatBlock.new()
	var gun: StatBlock = StatBlock.new()
	gear.add_modifier(&"fire_rate_pct", "increased", 0.2, &"charm")
	gun.add_modifier(&"fire_rate_pct", "increased", 0.2, &"gun")
	gun.add_modifier(&"fire_rate_pct", "more", 2.0, &"serum")
	assert_almost_eq(gun.value(&"fire_rate_pct", 10.0, gear), 26.0, 0.0001)


func test_caps_clamp_all_sources_after_buckets() -> void:
	var stats: StatBlock = StatBlock.new()
	stats.add_modifier(&"move_speed", "increased", 0.1, &"boots")
	stats.add_modifier(&"move_speed", "more", 1.1, &"serum")
	stats.add_modifier(&"move_speed", "flat", 2.0, &"ability")
	stats.add_modifier(&"leech", "flat", 4.0, &"gun")
	stats.add_modifier(&"leech", "flat", 4.0, &"charm")
	stats.add_modifier(&"damage_reduction", "flat", 0.5, &"vest")
	stats.add_modifier(&"ability_cooldown_reduction", "flat", 0.7, &"implant")
	stats.add_modifier(&"loot_luck", "flat", 2.0, &"charm")
	stats.add_modifier(&"bonus_skill_ranks", "flat", 4.0, &"vest")
	assert_almost_eq(stats.value(&"move_speed", 5.0), 5.75, 0.0001)
	assert_eq(stats.value(&"leech", 0.0), 6.0)
	assert_eq(stats.value(&"damage_reduction", 0.0), 0.3)
	assert_eq(stats.value(&"ability_cooldown_reduction", 0.0), 0.4)
	assert_eq(stats.value(&"loot_luck", 0.0), 1.0)
	assert_eq(stats.value(&"bonus_skill_ranks", 0.0), 3.0)


func test_fire_rate_caps_only_the_increased_bucket() -> void:
	var stats: StatBlock = StatBlock.new()
	stats.add_modifier(&"fire_rate_pct", "increased", 0.2, &"gun")
	stats.add_modifier(&"fire_rate_pct", "increased", 0.2, &"skill")
	stats.add_modifier(&"fire_rate_pct", "more", 2.0, &"serum")
	assert_almost_eq(stats.value(&"fire_rate_pct", 10.0), 26.0, 0.0001)


func test_removing_source_restores_its_values_and_keeps_other_sources() -> void:
	var stats: StatBlock = StatBlock.new()
	stats.add_modifier(&"health", "increased", 0.2, &"vest")
	stats.add_modifier(&"health", "flat", 20.0, &"vest")
	stats.add_modifier(&"health", "more", 2.0, &"serum")
	assert_almost_eq(stats.value(&"health", 100.0), 260.0, 0.0001)
	stats.remove_source(&"vest")
	assert_eq(stats.value(&"health", 100.0), 200.0)
	stats.remove_source(&"serum")
	stats.remove_source(&"absent")
	assert_eq(stats.value(&"health", 100.0), 100.0)


func test_proc_modifiers_are_dormant() -> void:
	var stats: StatBlock = StatBlock.new()
	stats.add_modifier(&"damage", "proc", 100.0, &"gun")
	assert_eq(stats.value(&"damage", 100.0), 100.0)


func test_external_multiplier_is_applied_before_flat_and_all_source_caps() -> void:
	var stats: StatBlock = StatBlock.new()
	stats.add_modifier(&"health", "flat", 40.0, &"vest")
	assert_eq(stats.value(&"health", 100.0, null, 2.0), 240.0)
	stats.add_modifier(&"move_speed", "increased", 0.3, &"vest")
	assert_almost_eq(stats.value(&"move_speed", 5.0, null, 0.9), 5.75, 0.0001)

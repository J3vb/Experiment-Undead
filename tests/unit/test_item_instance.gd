## Saved fractions decode using current content without changing saves or shared Resources.
extends GutTest


func test_percent_and_flat_affixes_use_current_tier_ranges() -> void:
	var item: ItemInstance = ItemInstance.new({"uid": "test", "aff": [["reload_pct", 5, 1.0], ["pellets", 5, 1.0]]})
	assert_almost_eq(item.value(&"reload_pct"), 1.2, 0.00001)
	assert_eq(item.value(&"pellets", 8.0), 10.0)
	item.stats.remove_source(&"test")
	assert_eq(item.value(&"reload_pct"), 1.0)
	assert_eq(item.value(&"pellets", 8.0), 8.0)


func test_implicit_uses_rarity_range_and_fraction() -> void:
	var common: ItemInstance = ItemInstance.new({"rar": "common", "imp": ["deep_reserve", 1.0]})
	var legendary: ItemInstance = ItemInstance.new({"rar": "legendary", "imp": ["deep_reserve", 0.0]})
	assert_eq(common.value(&"deep_reserve", 100.0), 150.0)
	assert_eq(legendary.value(&"deep_reserve", 100.0), 250.0)


func test_unknown_proc_traits_and_sets_remain_dormant() -> void:
	var saved: Dictionary = {
		"uid": "dormant",
		"rar": "rare",
		"aff": [["missing_affix", 1, 0.5], ["incendiary", 5, 1.0]],
		"imp": ["fabricator", 1.0],
		"trait": ["missing_trait", 0.5],
		"set": "missing_set",
	}
	var item: ItemInstance = ItemInstance.new(saved)
	assert_eq(item.data, saved)
	assert_true(item.stats.modifiers.is_empty())
	assert_eq(item.value(&"incendiary", 0.0), 0.0)
	assert_eq(item.value(&"fabricator", 0.0), 0.0)


func test_decoding_keeps_saved_dictionary_and_content_unchanged() -> void:
	var saved: Dictionary = {"aff": [["reload_pct", 1, 0.0]], "craft": {"future": [1, 2]}}
	var before: Dictionary = saved.duplicate(true)
	var content: AffixData = Content.get_item(&"loot", &"reload_pct") as AffixData
	var low: float = content.tiers[0].low
	var item: ItemInstance = ItemInstance.new(saved)
	item.data.aff[0][2] = 1.0
	item.data.craft.future.append(3)
	assert_eq(saved, before)
	assert_eq(content.tiers[0].low, low)
	assert_almost_eq(item.value(&"reload_pct"), 1.08, 0.00001)


func test_unknown_implicit_and_invalid_tiers_do_not_apply() -> void:
	var item: ItemInstance = ItemInstance.new(
		{"aff": [["reload_pct", 0, 1.0], ["reload_pct", 6, 1.0]], "imp": ["missing_implicit", 0.5]}
	)
	assert_true(item.stats.modifiers.is_empty())


func test_weapon_stat_converts_speed_bonuses_to_duration_factors() -> void:
	var item: ItemInstance = ItemInstance.new(
		{"aff": [["reload_pct", 5, 1.0], ["fire_rate_pct", 5, 1.0], ["ads_pct", 5, 1.0], ["handling_pct", 5, 1.0]]}
	)
	assert_almost_eq(item.weapon_stat(&"reload_time", 0.5), 0.5 / 1.2, 0.00001)
	assert_almost_eq(item.weapon_stat(&"fire_interval", 0.8), 0.8 / 1.1, 0.00001)
	assert_almost_eq(item.weapon_stat(&"ads_time", 0.75), 0.75 / 1.2, 0.00001)
	assert_almost_eq(item.weapon_stat(&"sprint_out_time", 0.75), 0.75 / 1.35, 0.00001)


func test_head_damage_and_unmapped_stats_apply_the_item_bonus_once() -> void:
	var item: ItemInstance = ItemInstance.new({"aff": [["hs_pct", 5, 1.0], ["dmg_pct", 5, 1.0]]})
	assert_almost_eq(item.weapon_stat(&"head_damage", 1.5), 1.95, 0.00001)
	assert_almost_eq(item.weapon_stat(&"dmg_pct", 100.0), 115.0, 0.00001)
	assert_eq(item.weapon_stat(&"reload_time", 0.5), 0.5)


func test_weapon_snapshot_applies_static_affixes_without_changing_content() -> void:
	var base: WeaponData = Content.weapon(&"pistol_service")
	var damage: float = base.damage
	var magazine: int = base.magazine_size
	var saved: Dictionary = {
		"rar": "common",
		"aff": [["dmg_pct", 5, 1.0], ["mag_pct", 5, 1.0], ["pellets", 5, 1.0]],
		"imp": ["deep_reserve", 1.0],
	}
	var item: ItemInstance = ItemInstance.new(saved)
	var snapshot: WeaponData = item.weapon_data(base)
	assert_ne(snapshot, base)
	assert_almost_eq(snapshot.damage, damage * 1.15, 0.00001)
	assert_almost_eq(snapshot.min_damage, base.min_damage * 1.15, 0.00001)
	assert_eq(snapshot.magazine_size, roundi(magazine * 1.3))
	assert_eq(snapshot.pellets, base.pellets + 2)
	assert_eq(snapshot.starting_reserve, roundi(base.starting_reserve * 1.5))
	assert_eq(snapshot.max_reserve, roundi(base.max_reserve * 1.5))
	assert_eq(base.damage, damage)
	assert_eq(base.magazine_size, magazine)
	assert_same(Content.weapon(&"pistol_service"), base)


func test_weapon_accuracy_snapshot_has_independent_recoil() -> void:
	var base: WeaponData = Content.weapon(&"rifle_ar")
	var pattern: Array[Vector2] = base.recoil.pattern.duplicate()
	var random_spread: Vector2 = base.recoil.random_spread
	var item: ItemInstance = ItemInstance.new(
		{"aff": [["hipfire_pct", 5, 1.0], ["falloff_pct", 5, 1.0], ["recoil_pct", 5, 1.0]]}
	)
	var snapshot: WeaponData = item.weapon_data(base)
	assert_almost_eq(snapshot.hip_spread, base.hip_spread * 0.75, 0.00001)
	assert_almost_eq(snapshot.falloff_start, base.falloff_start * 1.3, 0.00001)
	assert_almost_eq(snapshot.falloff_end, base.falloff_end * 1.3, 0.00001)
	assert_ne(snapshot.recoil, base.recoil)
	assert_almost_eq(snapshot.recoil.pattern[0].x, pattern[0].x * 0.8, 0.00001)
	assert_almost_eq(snapshot.recoil.pattern[0].y, pattern[0].y * 0.8, 0.00001)
	assert_almost_eq(snapshot.recoil.random_spread.x, random_spread.x * 0.8, 0.00001)
	assert_almost_eq(snapshot.recoil.random_spread.y, random_spread.y * 0.8, 0.00001)
	assert_eq(base.recoil.pattern, pattern)
	assert_eq(base.recoil.random_spread, random_spread)


func test_weapon_snapshot_leaves_timer_and_head_stats_for_the_hook() -> void:
	var base: WeaponData = Content.weapon(&"pistol_service")
	var item: ItemInstance = ItemInstance.new(
		{"aff": [["reload_pct", 5, 1.0], ["ads_pct", 5, 1.0], ["hs_pct", 5, 1.0], ["fire_rate_pct", 5, 1.0]]}
	)
	var snapshot: WeaponData = item.weapon_data(base)
	assert_eq(snapshot.reload_time, base.reload_time)
	assert_eq(snapshot.empty_reload_time, base.empty_reload_time)
	assert_eq(snapshot.ads_time, base.ads_time)
	assert_eq(snapshot.head_multiplier, base.head_multiplier)
	assert_eq(snapshot.rounds_per_minute, base.rounds_per_minute)


func test_swap_time_reads_handling_and_serums_still_multiply() -> void:
	var stats: StatBlock = StatBlock.new()
	stats.add_modifier(&"handling_pct", "increased", 0.1, &"gloves")
	assert_almost_eq(ItemInstance.stat_value(stats, &"swap_time"), 1.0 / 1.1, 0.00001)
	assert_almost_eq(ItemInstance.stat_value(stats, &"swap_time", 1.0, null, 0.6), 0.6 / 1.1, 0.00001, "Quickhands")


func test_legendary_trait_loads_as_its_own_flat_stat_line() -> void:
	var low: ItemInstance = ItemInstance.new({"uid": "tw", "rar": "legendary", "trait": ["tidewater", 0.0]})
	var high: ItemInstance = ItemInstance.new({"uid": "tw", "rar": "legendary", "trait": ["tidewater", 1.0]})
	assert_eq(low.stats.value(&"tidewater", 0.0), 3.0)
	assert_eq(high.stats.value(&"tidewater", 0.0), 5.0)
	assert_eq(ItemInstance.legendary_of(high.data).display_name, "Tidewater")
	high.stats.remove_source(&"tw")
	assert_eq(high.stats.value(&"tidewater", 0.0), 0.0)


func test_legendary_trait_survives_a_save_round_trip() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var item: Dictionary = ItemRoller.roll_weapon(rng, Content.weapon(&"rifle_ar"), &"legendary", 20)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(item))
	var before: float = ItemInstance.new(item).stats.value(&"tidewater", 0.0)
	assert_gt(before, 0.0)
	assert_eq(ItemInstance.new(saved).stats.value(&"tidewater", 0.0), before)
	assert_eq(LootDrop.item_name(saved), "Tidewater")


func test_bad_or_unknown_trait_lines_add_nothing() -> void:
	for line: Variant in [null, [], ["tidewater"], ["future_legendary", 0.5], ["dmg_pct", 0.5]]:
		var item: ItemInstance = ItemInstance.new({"uid": "x", "trait": line})
		assert_true(item.stats.modifiers.is_empty())
		assert_null(ItemInstance.legendary_of(item.data))

## Validates weapon loot Resources and their design contracts before any drops exist.
extends GutTest

const GATES: Array[int] = [1, 8, 15, 22, 30]
const COLOURS: Array[String] = ["d9d9d2", "3fe0c8", "3d7dff", "a64dff", "ff8a1c", "8dff3a"]


func test_loot_ids_are_unique_across_subfolders() -> void:
	var paths: Array[String] = []
	_collect("res://content/loot", paths)
	var seen: Array[StringName] = []
	for path: String in paths:
		var resource: Resource = load(path)
		var id: StringName = resource.get("id")
		assert_false(seen.has(id), path + " has a unique id")
		seen.append(id)
		assert_eq(String(id), path.get_file().get_basename())
		assert_eq(Content.get_item(&"loot", id), resource)
	assert_eq(paths.size(), 79)
	assert_eq(Content.ids(&"loot").size(), paths.size())


func test_stat_caps_match_the_affix_design_table() -> void:
	var caps: StatCaps = Content.get_item(&"loot", &"stat_caps") as StatCaps
	assert_not_null(caps)
	assert_eq(
		caps.caps,
		{
			&"move_speed": 0.15,
			&"damage_reduction": 0.3,
			&"ability_cooldown_reduction": 0.4,
			&"loot_luck": 1.0,
			&"bonus_skill_ranks": 3.0,
			&"fire_rate_pct": 0.3,
			&"leech": 6.0,
			&"reload_pct": 1.6,
			&"recoil_pct": 1.5,
			&"max_health": 400.0,
			&"points_earned": 1.5,
		}
	)


func test_weapon_affixes_have_five_equal_rising_tiers() -> void:
	var kinds: Dictionary = {"prefix": 0, "suffix": 0, "implicit": 0}
	for id: StringName in Content.ids(&"loot"):
		var affix: AffixData = Content.get_item(&"loot", id) as AffixData
		if affix == null or not affix.slots.has(&"primary"):
			continue
		kinds[affix.kind] += 1
		assert_true(affix.single_value or affix.text.contains("{v}"), String(id))
		assert_ne(affix.family, &"")
		assert_ne(affix.stat, &"")
		assert_gt(affix.step, 0.0)
		assert_has(["increased", "more", "flat", "proc"], affix.op)
		if affix.kind == "implicit":
			assert_true(affix.tiers.is_empty())
			continue
		assert_eq(affix.tiers.size(), 5, String(id))
		assert_gt(affix.weight, 0.0)
		for index: int in affix.tiers.size():
			var tier: AffixTier = affix.tiers[index]
			assert_eq(tier.min_ilvl, GATES[index])
			assert_gt(tier.high, tier.low)
			assert_almost_eq(tier.high - tier.low, affix.tiers[0].high - affix.tiers[0].low, 0.00001)
			if index > 0:
				assert_almost_eq(tier.low, affix.tiers[index - 1].high, 0.00001)
	assert_eq(kinds, {"prefix": 12, "suffix": 10, "implicit": 3})


func test_rarity_shares_colours_and_counts() -> void:
	var zombie: float = 0.0
	var vault: float = 0.0
	var counts: Array[Dictionary] = [{0: 1.0}, {1: 1.0}, {2: 0.6, 3: 0.4}, {3: 0.5, 4: 0.5}, {4: 1.0}, {0: 1.0}]
	for index: int in ItemRoller.RARITIES.size():
		var rarity: RarityData = Content.get_item(&"loot", ItemRoller.RARITIES[index]) as RarityData
		assert_eq(rarity.colour.to_html(false), COLOURS[index])
		assert_eq(rarity.affix_count_weights, counts[index])
		assert_eq(rarity.tier_bonus, 1 if index in [3, 4] else 0)
		assert_gte(rarity.zombie_share, 0.0)
		assert_gte(rarity.vault_share, 0.0)
		zombie += rarity.zombie_share
		vault += rarity.vault_share
	assert_almost_eq(zombie, 1.0, 0.000001)
	assert_almost_eq(vault, 1.0, 0.000001)


func test_weapon_ranges_and_weights_match_the_affix_table() -> void:
	var expected: Dictionary = {
		&"dmg_pct": Vector3(5, 15, 100),
		&"hs_pct": Vector3(10, 30, 100),
		&"fire_rate_pct": Vector3(4, 10, 80),
		&"close_quarters_pct": Vector3(8, 20, 70),
		&"long_shot_pct": Vector3(8, 20, 70),
		&"elite_hunter_pct": Vector3(10, 30, 60),
		&"executioner_pct": Vector3(15, 40, 50),
		&"incendiary": Vector3(5, 15, 60),
		&"chain_shock": Vector3(5, 12, 60),
		&"frostbite": Vector3(5, 15, 60),
		&"penetration": Vector3(40, 70, 40),
		&"stagger_pct": Vector3(15, 40, 60),
		&"reload_pct": Vector3(8, 20, 100),
		&"mag_pct": Vector3(10, 30, 100),
		&"ads_pct": Vector3(8, 20, 90),
		&"recoil_pct": Vector3(8, 20, 90),
		&"hipfire_pct": Vector3(10, 25, 70),
		&"handling_pct": Vector3(15, 35, 70),
		&"falloff_pct": Vector3(10, 30, 60),
		&"points_per_hit": Vector3(1, 3, 60),
		&"leech": Vector3(1, 3, 60),
		&"pellets": Vector3(1, 2, 50),
	}
	for id: StringName in expected:
		var affix: AffixData = Content.get_item(&"loot", id) as AffixData
		var values: Vector3 = expected[id]
		assert_eq(affix.tiers[0].low, float(values.x), String(id))
		assert_eq(affix.tiers[4].high, float(values.y), String(id))
		assert_eq(affix.weight, float(values.z), String(id))


func test_ammo_has_the_design_ranges_and_weights_per_rarity() -> void:
	var ranges: Dictionary = {
		&"deep_reserve": [Vector2(30, 50), Vector2(50, 75), Vector2(75, 100), Vector2(100, 150), Vector2(150, 200)],
		&"reclaimer": [Vector2(15, 20), Vector2(20, 30), Vector2(30, 40), Vector2(40, 50), Vector2(50, 60)],
		&"fabricator": [Vector2(2, 3), Vector2(3, 4), Vector2(4, 5), Vector2(5, 7), Vector2(7, 9)],
	}
	var weights: Dictionary = {
		&"deep_reserve": [60.0, 50.0, 40.0, 30.0, 25.0],
		&"reclaimer": [30.0, 35.0, 35.0, 35.0, 35.0],
		&"fabricator": [10.0, 15.0, 25.0, 35.0, 40.0],
	}
	for id: StringName in ranges:
		var affix: AffixData = Content.get_item(&"loot", id) as AffixData
		assert_eq(affix.family, &"ammo")
		assert_eq(affix.rarity_ranges.size(), 5)
		assert_eq(affix.rarity_weights.size(), 5)
		for index: int in 5:
			var rarity: StringName = ItemRoller.RARITIES[index]
			assert_eq(affix.rarity_ranges[rarity], ranges[id][index])
			assert_eq(affix.rarity_weights[rarity], weights[id][index])


func test_every_weapon_has_tags_and_reforged_keeps_them() -> void:
	for id: StringName in Content.ids(&"weapons"):
		var weapon: WeaponData = Content.weapon(id)
		assert_false(weapon.loot_tags.is_empty(), String(id))
		if weapon.upgraded:
			assert_eq(weapon.loot_tags, weapon.upgraded.loot_tags)
	assert_eq(Content.weapon(&"brenner_trench").loot_tags, [&"shotgun", &"pump"])
	assert_eq(Content.weapon(&"talon_dmr").loot_tags, [&"rifle", &"dmr"])


func _collect(path: String, paths: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	for sub: String in dir.get_directories():
		_collect(path.path_join(sub), paths)
	for file: String in dir.get_files():
		var clean: String = file.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			paths.append(path.path_join(clean))

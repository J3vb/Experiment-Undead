## Seeded loot contracts, exclusions and observed roll distributions.
extends GutTest

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 73021


func test_same_seed_produces_same_plain_dictionary_and_rng_state() -> void:
	var other: RandomNumberGenerator = RandomNumberGenerator.new()
	other.seed = rng.seed
	for rarity: StringName in [&"common", &"uncommon", &"rare", &"epic", &"legendary"]:
		var first: Dictionary = ItemRoller.roll_weapon(rng, Content.weapon(&"rifle_ar"), rarity, 31)
		assert_eq(first, ItemRoller.roll_weapon(other, Content.weapon(&"rifle_ar"), rarity, 31))
		assert_eq(rng.state, other.state)
		assert_eq(first.size(), 10)
		assert_eq(first.v, 1)
		assert_eq(first.base, "rifle_ar")
		assert_eq(first.rar, String(rarity))
		assert_eq(first.ilvl, 31)
		assert_typeof(first.uid, TYPE_STRING)
		assert_null(first.trait)
		assert_null(first.set)
		assert_eq(first.craft, {})
		var saved: Dictionary = JSON.parse_string(JSON.stringify(first))
		assert_eq(saved.uid, first.uid)
		assert_eq(saved.base, first.base)
		assert_eq(saved.aff.size(), first.aff.size())
		assert_eq(int(saved.ilvl), first.ilvl)


func test_counts_families_kind_limits_and_weapon_restrictions() -> void:
	for id: StringName in Content.ids(&"weapons"):
		var weapon: WeaponData = Content.weapon(id)
		if weapon.loot_tags.has(&"prototype"):
			continue
		for rarity: StringName in [&"common", &"uncommon", &"rare", &"epic", &"legendary"]:
			if ItemRoller.RARITIES.find(rarity) < ItemRoller.RARITIES.find(weapon.get_meta(&"min_rarity", &"common")):
				assert_eq(ItemRoller.roll_weapon(rng, weapon, rarity, 30, 30), {})
				continue
			var data: RarityData = Content.get_item(&"loot", rarity) as RarityData
			for sample: int in 60:
				var item: Dictionary = ItemRoller.roll_weapon(rng, weapon, rarity, 30, 30)
				assert_has(data.affix_count_weights, item.aff.size())
				_check_lines(item, weapon)
				var ammo: AffixData = Content.get_item(&"loot", item.imp[0]) as AffixData
				assert_eq(item.imp.size(), 2)
				assert_eq(ammo.kind, "implicit")
				assert_gt(ammo.rarity_weights[rarity], 0.0)
				assert_between(float(item.imp[1]), 0.0, 1.0)


func _check_lines(item: Dictionary, weapon: WeaponData) -> void:
	var families: Array[StringName] = []
	var excluded: Array[StringName] = []
	var kinds: Dictionary = {"prefix": 0, "suffix": 0}
	var ids: Array[String] = []
	for line: Array in item.aff:
		assert_eq(line.size(), 3)
		var affix: AffixData = Content.get_item(&"loot", line[0]) as AffixData
		assert_true(affix.slots.has(&"primary") or affix.slots.has(&"sidearm"))
		assert_false(families.has(affix.family))
		assert_false(excluded.has(affix.family))
		for family: StringName in affix.exclusive_families:
			assert_false(families.has(family))
		families.append(affix.family)
		excluded.append_array(affix.exclusive_families)
		kinds[affix.kind] += 1
		ids.append(line[0])
		assert_between(int(line[1]), 1, 5)
		assert_between(float(line[2]), 0.0, 1.0)
	assert_lte(int(kinds.prefix), ceili(item.aff.size() / 2.0))
	assert_lte(int(kinds.suffix), ceili(item.aff.size() / 2.0))
	assert_false(ids.has("long_shot_pct") and ids.has("hipfire_pct"))
	if not weapon.loot_tags.has(&"shotgun"):
		assert_false(ids.has("pellets"))
	else:
		assert_false(ids.has("hs_pct"))
		assert_false(ids.has("long_shot_pct"))
		assert_false(ids.has("penetration"))
	if weapon.loot_tags.has(&"pump"):
		assert_false(ids.has("fire_rate_pct"))
	if weapon.loot_tags.has(&"belt"):
		assert_false(ids.has("mag_pct"))
	if weapon.loot_tags.has(&"smg"):
		assert_false(ids.has("long_shot_pct"))
		assert_false(ids.has("penetration"))
	if item.rar == "uncommon":
		assert_false(ids.has("penetration"))


func test_tier_gates_and_level_clamp() -> void:
	for level: int in [0, 5, 7, 8, 14, 15, 21, 22, 29, 30, 50, 100]:
		var highest: int = 1
		for gate: int in [8, 15, 22, 30]:
			if level >= gate:
				highest += 1
		for rarity: StringName in [&"rare", &"epic", &"legendary"]:
			for sample: int in 40:
				var item: Dictionary = ItemRoller.roll_weapon(rng, Content.weapon(&"rifle_ar"), rarity, level)
				assert_eq(item.ilvl, clampi(level, 1, 50))
				for line: Array in item.aff:
					assert_between(int(line[1]), 1, highest)
					if rarity != &"rare" and highest > 1:
						assert_gte(int(line[1]), 2)


func test_other_weapon_class_tags_filter_lines() -> void:
	for tags: Array in [[&"sniper", &"bolt"], [&"lmg"], [&"revolver", &"pistol"], [&"shotgun"]]:
		var weapon: WeaponData = WeaponData.new()
		weapon.id = &"tag_test"
		weapon.loot_tags.assign(tags)
		var seen: Array[String] = []
		for sample: int in 200:
			var item: Dictionary = ItemRoller.roll_weapon(rng, weapon, &"legendary", 30)
			for line: Array in item.aff:
				seen.append(line[0])
		if tags.has(&"bolt"):
			assert_false(seen.has("fire_rate_pct"))
			assert_false(seen.has("mag_pct"))
			assert_false(seen.has("hipfire_pct"))
		if tags.has(&"shotgun"):
			assert_has(seen, "pellets")
			assert_has(seen, "fire_rate_pct")
		else:
			assert_has(seen, "penetration")
			assert_false(seen.has("pellets"))


func test_affix_values_use_tier_ends_and_round_to_step() -> void:
	for id: StringName in Content.ids(&"loot"):
		var affix: AffixData = Content.get_item(&"loot", id) as AffixData
		if affix == null or affix.kind == "implicit":
			continue
		for index: int in 5:
			assert_almost_eq(ItemRoller.affix_value(id, index + 1, 0.0), affix.tiers[index].low, 0.00001)
			assert_almost_eq(ItemRoller.affix_value(id, index + 1, 1.0), affix.tiers[index].high, 0.00001)
	assert_eq(ItemRoller.affix_value(&"dmg_pct", 1, 0.3), 6.0)
	assert_almost_eq(ItemRoller.affix_value(&"fire_rate_pct", 1, 0.3), 4.4, 0.00001)


func test_rarity_shares_and_luck_for_both_sources() -> void:
	for vault: bool in [false, true]:
		for luck: float in [0.0, 1.0]:
			var observed: Dictionary = {}
			for sample: int in 20000:
				var id: StringName = ItemRoller.roll_rarity(rng, vault, luck)
				observed[id] = observed.get(id, 0) + 1
			var common: float = 0.4 if vault else 0.55
			var total: float = common + (1.0 - common) * (1.0 + luck)
			for id: StringName in ItemRoller.RARITIES:
				var data: RarityData = Content.get_item(&"loot", id) as RarityData
				var share: float = data.vault_share if vault else data.zombie_share
				var expected: float = share * (1.0 if id == &"common" else 1.0 + luck) / total
				assert_almost_eq(observed.get(id, 0) / 20000.0, expected, 0.015, "%s luck %s" % [id, luck])
			if luck > 0.0:
				assert_lt(observed[&"common"] / 20000.0, common)


func test_luck_is_clamped_and_seeded() -> void:
	var other: RandomNumberGenerator = RandomNumberGenerator.new()
	for luck: float in [-2.0, 4.0]:
		rng.seed = 917
		other.seed = 917
		for sample: int in 100:
			assert_eq(
				ItemRoller.roll_rarity(rng, false, luck), ItemRoller.roll_rarity(other, false, clampf(luck, 0, 1))
			)


func test_prototype_is_rejected_without_advancing_rng() -> void:
	var state: int = rng.state
	assert_eq(ItemRoller.roll_weapon(rng, Content.weapon(&"rifle_ar"), &"prototype", 30), {})
	assert_push_error("Prototypes are fixed items")
	assert_eq(rng.state, state)


func test_affix_count_tier_and_ammo_distributions() -> void:
	for rarity: StringName in [&"rare", &"epic"]:
		var tiers: Array[int] = [0, 0, 0, 0, 0]
		var counts: Dictionary = {}
		var ammo: Dictionary = {}
		for sample: int in 2000:
			var item: Dictionary = ItemRoller.roll_weapon(rng, Content.weapon(&"rifle_ar"), rarity, 30)
			counts[item.aff.size()] = counts.get(item.aff.size(), 0) + 1
			ammo[item.imp[0]] = ammo.get(item.imp[0], 0) + 1
			for line: Array in item.aff:
				tiers[line[1] - 1] += 1
		var expected: Array[float] = [0.04, 0.08, 0.18, 0.30, 0.40]
		if rarity == &"epic":
			expected = [0.0, 0.04, 0.08, 0.18, 0.70]
		var total: int = 0
		for count: int in tiers:
			total += count
		for index: int in 5:
			assert_almost_eq(float(tiers[index]) / total, expected[index], 0.025)
		assert_almost_eq(counts[2 if rarity == &"rare" else 3] / 2000.0, 0.6 if rarity == &"rare" else 0.5, 0.03)
		for id: StringName in [&"deep_reserve", &"reclaimer", &"fabricator"]:
			var affix: AffixData = Content.get_item(&"loot", id) as AffixData
			assert_almost_eq(ammo[String(id)] / 2000.0, affix.rarity_weights[rarity] / 100.0, 0.03)


func test_gear_rolls_repeat_as_plain_item_dicts_without_implicit_ammo() -> void:
	var other: RandomNumberGenerator = RandomNumberGenerator.new()
	other.seed = rng.seed
	for base: GearBaseData in _gear_bases():
		var original: String = var_to_str(base)
		for rarity: StringName in [&"common", &"uncommon", &"rare", &"epic", &"legendary"]:
			var item: Dictionary = ItemRoller.roll_gear(rng, base, rarity, 31)
			assert_eq(item, ItemRoller.roll_gear(other, base, rarity, 31))
			assert_eq(rng.state, other.state)
			assert_eq(item.size(), 10)
			assert_eq(item.v, 1)
			assert_eq(item.base, String(base.id))
			assert_eq(item.rar, String(rarity))
			assert_eq(item.ilvl, 31)
			assert_typeof(item.uid, TYPE_STRING)
			assert_null(item.imp)
			assert_null(item.trait)
			assert_null(item.set)
			assert_eq(item.craft, {})
			var saved: Dictionary = JSON.parse_string(JSON.stringify(item, "", true, true))
			assert_eq(saved.uid, item.uid)
			assert_eq(int(saved.v), item.v)
			assert_eq(int(saved.ilvl), item.ilvl)
			assert_eq(saved.aff.size(), item.aff.size())
			for index: int in item.aff.size():
				assert_eq(saved.aff[index][0], item.aff[index][0])
				assert_eq(int(saved.aff[index][1]), int(item.aff[index][1]))
				assert_almost_eq(float(saved.aff[index][2]), float(item.aff[index][2]), 0.000000000001)
		assert_eq(var_to_str(base), original)


func test_gear_counts_slots_families_kinds_and_level_gates() -> void:
	var seen: Array[StringName] = []
	for id: StringName in [&"vest_light", &"charm_coin", &"implant_reflex"]:
		var base: GearBaseData = Content.get_item(&"loot", id) as GearBaseData
		for rarity: StringName in [&"common", &"uncommon", &"rare", &"epic", &"legendary"]:
			var data: RarityData = Content.get_item(&"loot", rarity) as RarityData
			for level: int in [0, 7, 8, 14, 15, 21, 22, 29, 30, 100]:
				for sample: int in 10:
					var item: Dictionary = ItemRoller.roll_gear(rng, base, rarity, level)
					assert_has(data.affix_count_weights, item.aff.size())
					assert_eq(item.ilvl, clampi(level, 1, 50))
					_check_gear_lines(item, base, seen)
	for id: String in DirAccess.get_files_at("res://content/loot/affixes/gear"):
		if id.ends_with(".tres"):
			assert_has(seen, StringName(id.get_basename()))


func _check_gear_lines(item: Dictionary, base: GearBaseData, seen: Array[StringName]) -> void:
	var families: Array[StringName] = []
	var kinds: Dictionary = {"prefix": 0, "suffix": 0}
	var highest: int = 1
	for gate: int in [8, 15, 22, 30]:
		if item.ilvl >= gate:
			highest += 1
	for line: Array in item.aff:
		assert_eq(line.size(), 3)
		var affix: AffixData = Content.get_item(&"loot", line[0]) as AffixData
		assert_has(affix.slots, StringName(base.slot))
		assert_false(families.has(affix.family))
		families.append(affix.family)
		kinds[affix.kind] += 1
		seen.append(affix.id)
		assert_lte(affix.min_ilvl, int(item.ilvl))
		assert_gte(ItemRoller.RARITIES.find(StringName(item.rar)), ItemRoller.RARITIES.find(affix.min_rarity))
		assert_between(int(line[1]), 1, highest)
		assert_between(float(line[2]), 0.0, 1.0)
		if item.rar in ["epic", "legendary"] and highest > 1:
			assert_gte(int(line[1]), 2)
	assert_lte(int(kinds.prefix), ceili(item.aff.size() / 2.0))
	assert_lte(int(kinds.suffix), ceili(item.aff.size() / 2.0))


func test_gear_fixed_value_lines_retain_one_at_every_tier_and_fraction() -> void:
	for id: StringName in [&"skill_rank", &"extra_grenade"]:
		for tier: int in range(1, 6):
			for q: float in [0.0, 0.5, 1.0]:
				assert_eq(ItemRoller.affix_value(id, tier, q), 1.0)


func test_gear_prototype_is_rejected_without_advancing_rng() -> void:
	var state: int = rng.state
	assert_eq(ItemRoller.roll_gear(rng, _gear_bases()[0], &"prototype", 30), {})
	assert_push_error("Prototypes are fixed items")
	assert_eq(rng.state, state)


func test_slot_for_maps_every_gear_base_and_weapon() -> void:
	for base: GearBaseData in _gear_bases():
		assert_eq(Inventory.slot_for(ItemRoller.roll_gear(rng, base, &"rare", 30)), StringName(base.slot))
	assert_eq(Inventory.slot_for({"base": "rifle_ar"}), &"primary")
	assert_eq(Inventory.slot_for({"base": "hollis_44"}), &"sidearm")
	assert_eq(Inventory.slot_for({"base": "unknown_base"}), &"")
	assert_eq(Inventory.slot_for({}), &"")


## Bases that roll today; the F-71 slots get their affix pools (and drop weight) in step 4.
func _gear_bases() -> Array[GearBaseData]:
	var bases: Array[GearBaseData] = []
	for id: StringName in Content.ids(&"loot"):
		var base: GearBaseData = Content.get_item(&"loot", id) as GearBaseData
		if base != null and base.drop_weight > 0.0:
			bases.append(base)
	return bases


func test_unknown_affix_or_tier_from_a_newer_save_is_worth_zero() -> void:
	assert_eq(ItemRoller.affix_value(&"test_future_affix", 1, 0.5), 0.0)
	assert_eq(ItemRoller.affix_value(&"dmg_pct", 0, 0.5), 0.0)
	assert_eq(ItemRoller.affix_value(&"dmg_pct", 99, 0.5), 0.0)

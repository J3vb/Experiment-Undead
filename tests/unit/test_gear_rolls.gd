## Seeded gear rolls: plain item dicts, slot pools, kinds and level gates for every gear slot.
extends GutTest

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 73021


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
			if rarity == &"legendary" and not ItemRoller.legendaries_for(base.id).is_empty():
				assert_eq(ItemInstance.legendary_of(item).base_id, base.id)
			else:
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
	for base: GearBaseData in _one_base_per_slot():
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


func test_new_slot_legendaries_roll_two_prefixes_and_two_suffixes_from_their_pool() -> void:
	var pools: Dictionary[StringName, Array] = {
		&"headgear_cap": [&"max_health", &"steady_aim", &"regen_delay", &"reload_focus"],
		&"gloves_tactical": [&"recoil_grip", &"steady_aim", &"reload_focus", &"quick_hands"],
		&"backpack_pack": [&"max_health", &"damage_reduction", &"mule", &"sprint_duration"],
		&"boots_field": [&"max_health", &"damage_reduction", &"move_speed", &"sprint_duration"],
	}
	for id: StringName in pools:
		var base: GearBaseData = Content.get_item(&"loot", id) as GearBaseData
		for _roll: int in 10:
			var item: Dictionary = ItemRoller.roll_gear(rng, base, &"legendary", 30)
			var kinds: Dictionary = {"prefix": 0, "suffix": 0}
			var rolled: PackedStringArray = []
			for line: Array in item.aff:
				var affix_id: StringName = StringName(line[0])
				assert_has(pools[id], affix_id, String(id))
				var affix: AffixData = Content.get_item(&"loot", affix_id) as AffixData
				kinds[affix.kind] += 1
				rolled.append(String(affix_id))
			assert_eq(kinds, {"prefix": 2, "suffix": 2}, String(id))
			rolled.sort()
			var expected: PackedStringArray = PackedStringArray(pools[id])
			expected.sort()
			assert_eq(rolled, expected, String(id) + " fills its whole pool")


func _one_base_per_slot() -> Array[GearBaseData]:
	var bases: Array[GearBaseData] = []
	var slots: Array[StringName] = []
	for base: GearBaseData in _gear_bases():
		if not slots.has(StringName(base.slot)):
			slots.append(StringName(base.slot))
			bases.append(base)
	assert_eq(bases.size(), CharacterProfile.GEAR_SLOTS.size())
	return bases


func _gear_bases() -> Array[GearBaseData]:
	var bases: Array[GearBaseData] = []
	for id: StringName in Content.sorted_ids(&"loot"):
		var base: GearBaseData = Content.get_item(&"loot", id) as GearBaseData
		if base != null:
			bases.append(base)
	return bases

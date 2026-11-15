## Seeded weapon and gear loot as save/network dictionaries. Only the caller's RNG advances.
class_name ItemRoller
extends RefCounted

const RARITIES: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"prototype"]
const TIER_WEIGHTS: Array[float] = [40.0, 30.0, 18.0, 8.0, 4.0]


static func roll_rarity(rng: RandomNumberGenerator, vault: bool, luck: float) -> StringName:
	var weights: Array[float] = []
	for id: StringName in RARITIES:
		var rarity: RarityData = Content.get_item(&"loot", id) as RarityData
		var share: float = rarity.vault_share if vault else rarity.zombie_share
		weights.append(share * (1.0 if id == &"common" else 1.0 + clampf(luck, 0.0, 1.0)))
	return RARITIES[_pick_index(rng, weights)]


static func roll_weapon(
	rng: RandomNumberGenerator, weapon: WeaponData, rarity_id: StringName, item_level: int
) -> Dictionary:
	if rarity_id == &"prototype" or weapon.loot_tags.has(&"prototype"):
		push_error("ItemRoller: Prototypes are fixed items, not random weapon rolls")
		return {}
	var rarity: RarityData = Content.get_item(&"loot", rarity_id) as RarityData
	if rarity == null:
		return {}
	var level: int = clampi(item_level, 1, 50)
	var ids: Array = Content.ids(&"loot")
	ids.sort()
	var affixes: Array[AffixData] = []
	var ammo: Array[AffixData] = []
	for id: StringName in ids:
		var affix: AffixData = Content.get_item(&"loot", id) as AffixData
		if affix == null:
			continue
		if not (affix.slots.has(&"primary") or affix.slots.has(&"sidearm")) or affix.min_ilvl > level:
			continue
		if affix.kind == "implicit":
			ammo.append(affix)
		else:
			affixes.append(affix)
	return {
		"v": 1,
		"uid": "%08x-%08x-%08x-%08x" % [rng.randi(), rng.randi(), rng.randi(), rng.randi()],
		"base": String(weapon.id),
		"rar": String(rarity_id),
		"ilvl": level,
		"aff": _roll_affixes(rng, affixes, weapon.loot_tags, rarity, level),
		"imp": _roll_ammo(rng, ammo, rarity_id),
		"trait": null,
		"set": null,
		"craft": {},
	}


static func roll_gear(
	rng: RandomNumberGenerator, base: GearBaseData, rarity_id: StringName, item_level: int
) -> Dictionary:
	if rarity_id == &"prototype":
		push_error("ItemRoller: Prototypes are fixed items, not random gear rolls")
		return {}
	var rarity: RarityData = Content.get_item(&"loot", rarity_id) as RarityData
	if rarity == null:
		return {}
	var level: int = clampi(item_level, 1, 50)
	var ids: Array = Content.ids(&"loot")
	ids.sort()
	var affixes: Array[AffixData] = []
	for id: StringName in ids:
		var affix: AffixData = Content.get_item(&"loot", id) as AffixData
		if affix == null or affix.kind == "implicit":
			continue
		if affix.slots.has(StringName(base.slot)) and affix.min_ilvl <= level:
			affixes.append(affix)
	return {
		"v": 1,
		"uid": "%08x-%08x-%08x-%08x" % [rng.randi(), rng.randi(), rng.randi(), rng.randi()],
		"base": String(base.id),
		"rar": String(rarity_id),
		"ilvl": level,
		"aff": _roll_affixes(rng, affixes, base.loot_tags, rarity, level),
		"imp": null,
		"trait": null,
		"set": null,
		"craft": {},
	}


static func affix_value(affix_id: StringName, tier: int, q: float) -> float:
	var affix: AffixData = Content.get_item(&"loot", affix_id) as AffixData
	var data: AffixTier = affix.tiers[tier - 1]
	return snappedf(lerpf(data.low, data.high, q), affix.step)


static func _roll_affixes(
	rng: RandomNumberGenerator, affixes: Array[AffixData], tags: Array[StringName], rarity: RarityData, level: int
) -> Array:
	var counts: Array = rarity.affix_count_weights.keys()
	counts.sort()
	var count_weights: Array[float] = []
	for count: int in counts:
		count_weights.append(rarity.affix_count_weights[count])
	var count: int = counts[_pick_index(rng, count_weights)]
	var chosen: Array[AffixData] = []
	var lines: Array = []
	for line: int in count:
		var pool: Array[AffixData] = _pool(affixes, chosen, tags, rarity.id, ceili(count / 2.0))
		if pool.is_empty():
			push_error("ItemRoller: no eligible affixes for %s" % rarity.id)
			return []
		var weights: Array[float] = []
		for affix: AffixData in pool:
			weights.append(affix.weight)
		var affix: AffixData = pool[_pick_index(rng, weights)]
		chosen.append(affix)
		lines.append([String(affix.id), _roll_tier(rng, affix, level, rarity.tier_bonus), rng.randf()])
	return lines


static func _pool(
	affixes: Array[AffixData], chosen: Array[AffixData], tags: Array[StringName], rarity: StringName, kind_limit: int
) -> Array[AffixData]:
	var pool: Array[AffixData] = []
	for affix: AffixData in affixes:
		if RARITIES.find(rarity) < RARITIES.find(affix.min_rarity) or not _tags_fit(affix, tags):
			continue
		var kind_count: int = 0
		var excluded: bool = false
		for previous: AffixData in chosen:
			if previous.kind == affix.kind:
				kind_count += 1
			if (
				previous.family == affix.family
				or previous.exclusive_families.has(affix.family)
				or affix.exclusive_families.has(previous.family)
			):
				excluded = true
		if not excluded and kind_count < kind_limit:
			pool.append(affix)
	return pool


static func _tags_fit(affix: AffixData, tags: Array[StringName]) -> bool:
	for tag: StringName in affix.blocked_tags:
		if tags.has(tag):
			return false
	if affix.allowed_tags.is_empty():
		return true
	for tag: StringName in affix.allowed_tags:
		if tags.has(tag):
			return true
	return false


static func _roll_tier(rng: RandomNumberGenerator, affix: AffixData, level: int, bonus: int) -> int:
	var highest: int = 0
	for tier: AffixTier in affix.tiers:
		if tier.min_ilvl <= level:
			highest += 1
	var weights: Array[float] = []
	for offset: int in highest:
		weights.append(TIER_WEIGHTS[offset])
	return mini(highest - _pick_index(rng, weights) + bonus, highest)


static func _roll_ammo(rng: RandomNumberGenerator, ammo: Array[AffixData], rarity: StringName) -> Array:
	var weights: Array[float] = []
	for affix: AffixData in ammo:
		weights.append(affix.rarity_weights.get(rarity, 0.0))
	return [String(ammo[_pick_index(rng, weights)].id), rng.randf()]


static func _pick_index(rng: RandomNumberGenerator, weights: Array[float]) -> int:
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	var roll: float = rng.randf() * total
	for index: int in weights.size():
		if weights[index] <= 0.0:
			continue
		roll -= weights[index]
		if roll < 0.0:
			return index
	return weights.size() - 1

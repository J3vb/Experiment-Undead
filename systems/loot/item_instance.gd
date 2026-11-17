## A saved item's current affix values; shared content and the saved dictionary stay unchanged.
class_name ItemInstance
extends RefCounted

const TIMING_STATS: Dictionary[StringName, StringName] = {
	&"reload_time": &"reload_pct",
	&"fire_interval": &"fire_rate_pct",
	&"ads_time": &"ads_pct",
	&"sprint_out_time": &"handling_pct",
}

var data: Dictionary
var stats: StatBlock = StatBlock.new()


func _init(item: Dictionary) -> void:
	data = item.duplicate(true)
	for line: Array in data.get("aff", []):
		_load_affix(line)
	var implicit: Variant = data.get("imp")
	if implicit is Array:
		_load_implicit(implicit)


func value(stat: StringName, base: float = 1.0, extra: StatBlock = null) -> float:
	return stats.value(stat, base, extra)


func weapon_stat(stat: StringName, base: float = 1.0, extra: StatBlock = null) -> float:
	return stat_value(stats, stat, base, extra)


static func stat_value(
	block: StatBlock, stat: StringName, base: float = 1.0, extra: StatBlock = null, multiplier: float = 1.0
) -> float:
	if TIMING_STATS.has(stat):
		return base * multiplier / maxf(block.value(TIMING_STATS[stat], 1.0, extra), 0.01)
	if stat == &"head_damage":
		return block.value(&"hs_pct", base, extra, multiplier)
	return block.value(stat, base, extra, multiplier)


func weapon_data(base: WeaponData, extra: StatBlock = null) -> WeaponData:
	var result: WeaponData = base.duplicate() as WeaponData
	result.damage = value(&"dmg_pct", base.damage, extra)
	result.min_damage = value(&"dmg_pct", base.min_damage, extra)
	result.magazine_size = (
		2 if base.loot_tags.has(&"double") else maxi(roundi(value(&"mag_pct", base.magazine_size, extra)), 1)
	)
	result.starting_reserve = maxi(roundi(value(&"deep_reserve", base.starting_reserve, extra)), 0)
	result.max_reserve = maxi(roundi(value(&"deep_reserve", base.max_reserve, extra)), 0)
	result.pellets = maxi(roundi(value(&"pellets", base.pellets, extra)), 1)
	result.hip_spread = base.hip_spread * maxf(2.0 - value(&"hipfire_pct", 1.0, extra), 0.0)
	result.falloff_start = value(&"falloff_pct", base.falloff_start, extra)
	result.falloff_end = value(&"falloff_pct", base.falloff_end, extra)
	if base.recoil:
		result.recoil = _recoil_data(base.recoil, extra)
	return result


func _recoil_data(base: RecoilData, extra: StatBlock) -> RecoilData:
	var result: RecoilData = base.duplicate() as RecoilData
	var scale: float = maxf(2.0 - value(&"recoil_pct", 1.0, extra), 0.0)
	result.pattern = []
	for kick: Vector2 in base.pattern:
		result.pattern.append(kick * scale)
	result.random_spread = base.random_spread * scale
	return result


func _load_affix(line: Array) -> void:
	if line.size() != 3:
		return
	var affix: AffixData = _affix(StringName(line[0]))
	if affix == null:
		return
	var tier: int = int(line[1])
	if tier < 1 or tier > affix.tiers.size():
		return
	_add(affix, ItemRoller.affix_value(affix.id, tier, clampf(float(line[2]), 0.0, 1.0)))


func _load_implicit(line: Array) -> void:
	if line.size() != 2:
		return
	var affix: AffixData = _affix(StringName(line[0]))
	var rarity: StringName = StringName(data.get("rar", "common"))
	if affix == null or not affix.rarity_ranges.has(rarity):
		return
	var limits: Vector2 = affix.rarity_ranges[rarity]
	var rolled: float = snappedf(lerpf(limits.x, limits.y, clampf(float(line[1]), 0.0, 1.0)), affix.step)
	_add(affix, rolled)


func _affix(id: StringName) -> AffixData:
	if not Content.has(&"loot", id):
		return null
	return Content.get_item(&"loot", id) as AffixData


func _add(affix: AffixData, rolled: float) -> void:
	if affix.op == "proc":
		return
	if affix.op == "increased":
		rolled /= 100.0
	elif affix.op == "more":
		rolled = 1.0 + rolled / 100.0
	elif affix.op == "flat" and affix.stat == &"regen_delay":
		rolled = -rolled
	stats.add_modifier(affix.stat, affix.op, rolled, StringName(data.get("uid", "")))

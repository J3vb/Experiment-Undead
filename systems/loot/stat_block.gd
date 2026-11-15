## Runtime modifiers: increased fractions add, more factors multiply, then flat units add.
class_name StatBlock
extends RefCounted

const CAPS: StatCaps = preload("res://content/loot/stat_caps.tres")

var modifiers: Array[Modifier] = []


func add_modifier(stat: StringName, op: String, amount: float, source: StringName) -> void:
	modifiers.append(Modifier.new(stat, op, amount, source))


func remove_source(source: StringName) -> void:
	for index: int in range(modifiers.size() - 1, -1, -1):
		if modifiers[index].source == source:
			modifiers.remove_at(index)


func value(stat: StringName, base: float = 1.0, extra: StatBlock = null, multiplier: float = 1.0) -> float:
	var totals: Vector3 = _totals(stat)
	if extra:
		var added: Vector3 = extra._totals(stat)
		totals.x += added.x
		totals.y *= added.y
		totals.z += added.z
	if stat == &"fire_rate_pct":
		totals.x = minf(totals.x, CAPS.caps[stat])
	var result: float = base * (1.0 + totals.x) * totals.y * multiplier + totals.z
	return _apply_cap(stat, base, result)


func _totals(stat: StringName) -> Vector3:
	var totals: Vector3 = Vector3(0.0, 1.0, 0.0)
	for modifier: Modifier in modifiers:
		if modifier.stat != stat:
			continue
		match modifier.op:
			"increased":
				totals.x += modifier.value
			"more":
				totals.y *= modifier.value
			"flat":
				totals.z += modifier.value
	return totals


func _apply_cap(stat: StringName, base: float, result: float) -> float:
	if stat == &"move_speed":
		return minf(result, base * (1.0 + CAPS.caps[stat]))
	if stat != &"fire_rate_pct" and CAPS.caps.has(stat):
		return minf(result, CAPS.caps[stat])
	return result

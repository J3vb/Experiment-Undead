## Turns skill ranks into StatBlock modifiers and a set of rules; never changes ranks or loaded content.
class_name SkillEffects
extends RefCounted

const SOURCE: StringName = &"skill"
## The design's 54 points at level 50.
const MAX_POINTS: int = 54


## Adds every ranked stat skill to stats. Percent values divide by 100, like gear affixes.
static func add_to(stats: StatBlock, ranks: Dictionary[StringName, int]) -> void:
	for node_id: StringName in ranks:
		var node: SkillNodeData = _node(node_id)
		if node == null or node.stat == &"" or ranks[node_id] <= 0:
			continue
		var amount: float = node.per_rank * ranks[node_id]
		if node.op == "increased":
			amount /= 100.0
		elif node.op == "more":
			amount = 1.0 + amount / 100.0
		elif node.op == "flat" and node.stat == &"regen_delay":
			amount = -amount
		stats.add_modifier(node.stat, node.op, amount, SOURCE)


## The rules of every ranked rule skill, as a set for one-lookup checks.
static func rules_for(ranks: Dictionary[StringName, int]) -> Dictionary[int, bool]:
	var rules: Dictionary[int, bool] = {}
	for node_id: StringName in ranks:
		var node: SkillNodeData = _node(node_id)
		if node and node.rule != SkillNodeData.Rule.NONE and ranks[node_id] > 0:
			rules[node.rule] = true
	return rules


## Ranks from a save or the network: String keys become StringName; unknown ids and bad ranks are dropped.
static func ranks_from(raw: Dictionary) -> Dictionary[StringName, int]:
	var ranks: Dictionary[StringName, int] = {}
	for key: Variant in raw:
		var node: SkillNodeData = _node(StringName(str(key)))
		var value: Variant = raw[key]
		if node == null or not (value is int or value is float):
			continue
		var rank: int = clampi(int(value), 0, node.max_ranks)
		if rank > 0:
			ranks[node.id] = rank
	return ranks


## Why a sent rank set is refused, or "" when it is fine.
static func ranks_problem(raw: Dictionary) -> String:
	var total: int = 0
	for key: Variant in raw:
		var node: SkillNodeData = _node(StringName(str(key)))
		if node == null:
			return "unknown_skill"
		var value: Variant = raw[key]
		if not value is int or int(value) < 1 or int(value) > node.max_ranks:
			return "bad_rank"
		total += int(value)
	return "too_many_points" if total > MAX_POINTS else ""


static func _node(node_id: StringName) -> SkillNodeData:
	if not Content.has(&"skills", node_id):
		return null
	return Content.get_item(&"skills", node_id) as SkillNodeData

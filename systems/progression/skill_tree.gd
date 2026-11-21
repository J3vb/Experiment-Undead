## Skill spending rules over rank dictionaries; never changes ranks or loaded content.
class_name SkillTree
extends RefCounted

const XP_RULES: XpRules = preload("res://content/progression/xp_rules.tres")


static func points_available(level: int, ranks: Dictionary[StringName, int]) -> int:
	var spent: int = 0
	for rank: int in ranks.values():
		spent += rank
	return XP_RULES.skill_points_for_level(level) - spent


static func points_in_branch(ranks: Dictionary[StringName, int], branch: StringName) -> int:
	var spent: int = 0
	for node_id: StringName in Content.ids(&"skills"):
		var node: SkillNodeData = Content.get_item(&"skills", node_id) as SkillNodeData
		if node.branch == branch:
			spent += ranks.get(node_id, 0)
	return spent


static func can_rank_up(ranks: Dictionary[StringName, int], node_id: StringName, level: int) -> bool:
	if not Content.has(&"skills", node_id) or points_available(level, ranks) < 1:
		return false
	var node: SkillNodeData = Content.get_item(&"skills", node_id) as SkillNodeData
	var rank: int = ranks.get(node_id, 0)
	if rank >= node.max_ranks:
		return false
	for required_id: StringName in node.requires:
		if ranks.get(required_id, 0) < 1:
			return false
	return points_in_branch(ranks, node.branch) - rank >= node.branch_points_needed


static func rank_up(ranks: Dictionary[StringName, int], node_id: StringName, level: int) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = ranks.duplicate()
	if can_rank_up(ranks, node_id, level):
		result[node_id] = result.get(node_id, 0) + 1
	return result


static func respec() -> Dictionary[StringName, int]:
	return {}


## True when node_id holds a rank added since the last save and taking it off keeps every
## other rank's prerequisites and branch gate met.
static func can_rank_down(
	pending: Dictionary[StringName, int], saved: Dictionary[StringName, int], node_id: StringName
) -> bool:
	if pending.get(node_id, 0) <= saved.get(node_id, 0):
		return false
	var after: Dictionary[StringName, int] = pending.duplicate()
	after[node_id] -= 1
	return ranks_hold(after)


static func rank_down(
	pending: Dictionary[StringName, int], saved: Dictionary[StringName, int], node_id: StringName
) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = pending.duplicate()
	if can_rank_down(pending, saved, node_id):
		result[node_id] -= 1
		if result[node_id] == 0:
			result.erase(node_id)
	return result


## True when every ranked node still has its prerequisites and its branch gate met.
static func ranks_hold(ranks: Dictionary[StringName, int]) -> bool:
	for node_id: StringName in ranks:
		var rank: int = ranks[node_id]
		if rank <= 0 or not Content.has(&"skills", node_id):
			continue
		var node: SkillNodeData = Content.get_item(&"skills", node_id) as SkillNodeData
		for required_id: StringName in node.requires:
			if ranks.get(required_id, 0) < 1:
				return false
		if points_in_branch(ranks, node.branch) - rank < node.branch_points_needed:
			return false
	return true

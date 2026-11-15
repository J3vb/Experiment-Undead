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
	if not Content.ids(&"skills").has(node_id) or points_available(level, ranks) < 1:
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

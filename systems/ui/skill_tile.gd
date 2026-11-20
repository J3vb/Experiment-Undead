## One skill on the Research screen: its name, ranks held and whether it can take a rank.
class_name SkillTile
extends Button

var node: SkillNodeData


func _init(skill: SkillNodeData) -> void:
	node = skill
	name = String(skill.id)
	custom_minimum_size = Vector2(220, 84)
	focus_mode = Control.FOCUS_ALL
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Repaints the tile. locked: the branch gate is not met yet.
func show_rank(rank: int, locked: bool) -> void:
	var line: String = "%d/%d" % [rank, node.max_ranks]
	if locked:
		line = "Needs %d in branch" % node.branch_points_needed
	text = "%s\n%s" % [node.display_name, line]
	modulate = Color(1, 1, 1, 0.45) if locked else Color.WHITE

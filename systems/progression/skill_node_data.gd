## One skill node. Per-rank values use the description's units (percent, seconds or flat amounts).
## A stat skill adds `per_rank` per rank to `stat` in the player's StatBlock; a rule skill names its rule.
class_name SkillNodeData
extends Resource

enum Rule { NONE, DEAD_CENTER, EXECUTION_LINE, LAST_STAND, UNDYING, BARGAIN_HUNTER, CHAIN_SUPPLY }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var branch: StringName = &"Marksman"
@export var row: int = 0
@export var column: int = 0
@export var max_ranks: int = 1
@export var requires: Array[StringName] = []
@export var branch_points_needed: int = 0
@export var stat: StringName = &""
@export var per_rank: float = 0.0
## How per_rank joins the stack: "increased" (percent, adds), "more" (percent, multiplies) or "flat" (units).
@export var op: String = "increased"
@export var rule: Rule = Rule.NONE
## White line icon on the Research tile (assets/ui/skills/<id>.svg), tinted at run time.
@export var icon: Texture2D

## One skill node. Per-rank values use the description's units (percent, seconds or flat amounts).
class_name SkillNodeData
extends Resource

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

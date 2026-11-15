## A gear base's loot identity and visual; rolled item state stays in a dictionary.
class_name GearBaseData
extends Resource

@export var id: StringName = &""
@export_enum("vest", "charm", "implant") var slot: String = "vest"
@export var display_name: String = "Gear"
@export var visual_id: StringName = &""
@export var loot_tags: Array[StringName] = []
@export var unlock_level: int = 1
@export var drop_weight: float = 100.0

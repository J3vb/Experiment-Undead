## A gear model and its attachment bone, independent of loot stats.
class_name GearVisual
extends Resource

@export var id: StringName = &""
@export_enum("vest", "charm", "implant") var slot: String = "vest"
@export var scene: PackedScene
@export var attach: StringName = &""
@export var set_id: StringName = &""

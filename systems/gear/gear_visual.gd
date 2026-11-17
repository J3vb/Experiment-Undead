## A gear model and its attachment bone, independent of loot stats.
class_name GearVisual
extends Resource

const BASES: Dictionary[StringName, StringName] = {
	&"vest": &"vest_medium", &"charm": &"charm_dog_tags", &"implant": &"implant_reflex"
}

@export var id: StringName = &""
@export var slot: StringName = &""
@export var scene: PackedScene
@export var attach: StringName = &""
@export var set_id: StringName = &""


static func find(visual_id: StringName) -> GearVisual:
	if not Content.has(&"gear_visuals", visual_id):
		return null
	return Content.get_item(&"gear_visuals", visual_id) as GearVisual


static func fallback(slot_id: StringName) -> GearVisual:
	return find(BASES.get(slot_id, &""))

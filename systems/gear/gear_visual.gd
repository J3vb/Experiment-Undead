## A body gear scene and its attachment bone; initial visuals use the available base pieces.
class_name GearVisual
extends Resource

const BASES: Dictionary[StringName, StringName] = {
	&"vest": &"vest_medium", &"charm": &"charm_dog_tags", &"implant": &"implant_reflex"
}
const SCENES: Dictionary[StringName, String] = {
	&"vest_light": "res://assets/models/gear/vest_light.glb",
	&"vest_medium": "res://assets/models/gear/vest_medium.glb",
	&"vest_heavy": "res://assets/models/gear/vest_heavy.glb",
	&"charm_dog_tags": "res://assets/models/gear/charm_dog_tags.glb",
	&"charm_vial": "res://assets/models/gear/charm_vial.glb",
	&"charm_keycard": "res://assets/models/gear/charm_keycard.glb",
	&"charm_dosimeter": "res://assets/models/gear/charm_dosimeter.glb",
	&"charm_coin": "res://assets/models/gear/charm_coin.glb",
	&"implant_reflex": "res://assets/models/gear/implant_reflex.glb",
	&"implant_lung": "res://assets/models/gear/implant_lung.glb",
	&"implant_spine": "res://assets/models/gear/implant_spine.glb",
	&"implant_ocular": "res://assets/models/gear/implant_ocular.glb",
	&"implant_relay": "res://assets/models/gear/implant_relay.glb",
}
const BONES: Dictionary[StringName, StringName] = {
	&"vest": &"spine_02", &"charm": &"spine_03", &"implant": &"forearm_L"
}

@export var id: StringName = &""
@export var slot: StringName = &""
@export var scene: PackedScene
@export var attach: StringName = &""


static func find(visual_id: StringName) -> GearVisual:
	if not SCENES.has(visual_id):
		return null
	var visual: GearVisual = GearVisual.new()
	visual.id = visual_id
	visual.slot = StringName(String(visual_id).get_slice("_", 0))
	visual.scene = load(SCENES[visual_id]) as PackedScene
	visual.attach = BONES[visual.slot]
	return visual


static func fallback(slot_id: StringName) -> GearVisual:
	return find(BASES.get(slot_id, &""))

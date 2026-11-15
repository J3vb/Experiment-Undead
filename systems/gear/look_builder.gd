## Converts equipped item dictionaries into appearance data without changing the items.
class_name LookBuilder
extends RefCounted

const EQUIPPED_SLOTS: Array[StringName] = [&"primary", &"sidearm", &"vest", &"charm", &"implant"]
## Initial base mapping until item base Resources exist; appearance never trusts item overrides.
const BASE_VISUALS: Dictionary[StringName, StringName] = {
	&"vest_light": &"vest_light",
	&"vest_medium": &"vest_medium",
	&"vest_heavy": &"vest_heavy",
	&"charm_dog_tags": &"charm_dog_tags",
	&"charm_vial": &"charm_vial",
	&"charm_keycard": &"charm_keycard",
	&"charm_dosimeter": &"charm_dosimeter",
	&"charm_coin": &"charm_coin",
	&"implant_reflex": &"implant_reflex",
	&"implant_lung": &"implant_lung",
	&"implant_spine": &"implant_spine",
	&"implant_ocular": &"implant_ocular",
	&"implant_relay": &"implant_relay",
}


static func from_equipped(loadout: Dictionary) -> CharacterLook:
	var look: CharacterLook = CharacterLook.new()
	for slot: StringName in EQUIPPED_SLOTS:
		var item: Dictionary = loadout.get(slot, {}) if loadout.get(slot) is Dictionary else {}
		if item.is_empty():
			continue
		var set_id: StringName = StringName(item.get("set", "")) if item.get("set") != null else &""
		if not set_id.is_empty():
			look.set_counts[set_id] = look.set_counts.get(set_id, 0) + 1
		if CharacterLook.SLOTS.has(slot):
			look.slots[slot] = _slot_look(slot, item)
	return look


static func _slot_look(slot: StringName, item: Dictionary) -> Dictionary:
	var base_id: StringName = StringName(item.get("base", ""))
	var visual: GearVisual = GearVisual.find(BASE_VISUALS.get(base_id, &""))
	var rarity: StringName = StringName(item.get("rar", "common"))
	if visual == null or visual.slot != slot:
		visual = GearVisual.fallback(slot)
		rarity = &"common"
	var dyes: Array[Color] = [CharacterLook.DEFAULT_DYE_MAIN, CharacterLook.DEFAULT_DYE_ACCENT]
	return {
		"visual_id": visual.id,
		"rarity": rarity,
		"dyes": dyes,
	}

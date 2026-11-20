## Converts equipped item dictionaries into appearance data without changing the items.
class_name LookBuilder
extends RefCounted


static func from_equipped(loadout: Dictionary) -> CharacterLook:
	var look: CharacterLook = CharacterLook.new()
	for slot: StringName in CharacterProfile.SLOTS:
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
	var base: GearBaseData = (
		Content.get_item(&"loot", base_id) as GearBaseData if Content.has(&"loot", base_id) else null
	)
	var visual: GearVisual = GearVisual.find(base.visual_id) if base else null
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

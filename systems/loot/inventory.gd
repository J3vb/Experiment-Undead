## Resolves an item dictionary's equipment slot from its base content.
class_name Inventory
extends RefCounted


static func slot_for(item: Dictionary) -> StringName:
	var id: StringName = StringName(item.get("base", ""))
	if Content.ids(&"loot").has(id):
		var base: GearBaseData = Content.get_item(&"loot", id) as GearBaseData
		if base != null:
			return StringName(base.slot)
	if Content.ids(&"weapons").has(id):
		var weapon: WeaponData = Content.weapon(id)
		return &"sidearm" if weapon.loot_tags.has(&"pistol") else &"primary"
	return &""

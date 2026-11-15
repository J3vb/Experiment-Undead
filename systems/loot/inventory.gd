## Fixed character stash and loadout moves. No match state or saving side effects.
class_name Inventory
extends RefCounted


static func add_to_stash(profile: CharacterProfile, item: Dictionary) -> int:
	if item.is_empty():
		return -1
	for slot: int in profile.stash.size():
		if profile.stash[slot].is_empty():
			var stored: Dictionary = item.duplicate(true)
			if not stored.has("acquired"):
				var newest: int = 0
				for index: int in profile.stash.size():
					var entry: Dictionary = profile.stash[index]
					if not entry.is_empty():
						newest = maxi(newest, int(entry.get("acquired", index)))
				for equipped: Dictionary in profile.loadout.values():
					newest = maxi(newest, int(equipped.get("acquired", 0)))
				stored["acquired"] = newest + 1
			profile.stash[slot] = stored
			return slot
	return -1


static func remove(profile: CharacterProfile, stash_slot: int) -> void:
	if stash_slot >= 0 and stash_slot < profile.stash.size():
		profile.stash[stash_slot] = {}


static func equip(profile: CharacterProfile, stash_slot: int) -> bool:
	if stash_slot < 0 or stash_slot >= profile.stash.size():
		return false
	var item: Dictionary = profile.stash[stash_slot]
	var slot: StringName = slot_for(item)
	if slot == &"":
		return false
	profile.stash[stash_slot] = profile.loadout[slot]
	profile.loadout[slot] = item
	return true


static func unequip(profile: CharacterProfile, slot: StringName) -> bool:
	if not profile.loadout.has(slot) or profile.loadout[slot].is_empty():
		return false
	for stash_slot: int in profile.stash.size():
		if profile.stash[stash_slot].is_empty():
			profile.stash[stash_slot] = profile.loadout[slot].duplicate(true)
			profile.loadout[slot] = {}
			return true
	return false


static func slot_for(item: Dictionary) -> StringName:
	var base: StringName = StringName(item.get("base", ""))
	if Content.ids(&"loot").has(base):
		var gear: GearBaseData = Content.get_item(&"loot", base) as GearBaseData
		if gear != null:
			return StringName(gear.slot)
	if not Content.ids(&"weapons").has(base):
		return &""
	var weapon: WeaponData = Content.weapon(base)
	match weapon.slot:
		WeaponData.Slot.PRIMARY:
			return &"primary"
		WeaponData.Slot.SIDEARM:
			return &"sidearm"
	return &""

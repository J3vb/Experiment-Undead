## Which stash items the Loadout screen shows, and in what order: guns or everything else (gear, and
## items whose base no longer exists), rarity filter, sort.
class_name CharacterStash
extends RefCounted

enum Kind { WEAPONS, GEAR }
enum Order { RARITY, ITEM_LEVEL, NEWEST }


## Stash indices to show. `rarity_filter` 0 is every rarity, else ItemRoller.RARITIES[rarity_filter - 1].
static func visible_indices(profile: CharacterProfile, kind: Kind, rarity_filter: int, order: Order) -> Array[int]:
	var indices: Array[int] = []
	if profile == null:
		return indices
	for index: int in profile.stash.size():
		var item: Dictionary = profile.stash[index]
		if item.is_empty():
			continue
		var weapon: bool = Content.has(&"weapons", StringName(item.get("base", "")))
		if weapon != (kind == Kind.WEAPONS):
			continue
		if rarity_filter > 0 and item.get("rar", "common") != ItemRoller.RARITIES[rarity_filter - 1]:
			continue
		indices.append(index)
	indices.sort_custom(func(left: int, right: int) -> bool: return comes_before(profile, left, right, order))
	return indices


static func comes_before(profile: CharacterProfile, left: int, right: int, order: Order) -> bool:
	if order == Order.NEWEST:
		var left_order: int = int(profile.stash[left].get("acquired", left))
		var right_order: int = int(profile.stash[right].get("acquired", right))
		return left_order > right_order if left_order != right_order else left > right
	var a: Dictionary = profile.stash[left]
	var b: Dictionary = profile.stash[right]
	var a_rarity: int = ItemRoller.RARITIES.find(StringName(a.get("rar", "common")))
	var b_rarity: int = ItemRoller.RARITIES.find(StringName(b.get("rar", "common")))
	var a_level: int = int(a.get("ilvl", 1))
	var b_level: int = int(b.get("ilvl", 1))
	if order == Order.ITEM_LEVEL and a_level != b_level:
		return a_level > b_level
	if a_rarity != b_rarity:
		return a_rarity > b_rarity
	return a_level > b_level if a_level != b_level else left > right

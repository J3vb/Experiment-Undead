## Legendary traits that change the owner's own gun (magazine, pellets, last round) and whether a reload
## asks for Cold Snap. Callers pass owner = true only on the gun's owner, like Dead Center; the server
## widens its claim bounds (HitClaims._trait_bounds). Takes the gun's parts, not the Weapon node.
class_name OwnerTraits
extends RefCounted


## The item trait's value, 0 without an item or off the owner.
static func value(item: ItemInstance, owner: bool, stat: StringName) -> float:
	return item.stats.value(stat, 0.0) if item and owner else 0.0


## Bottomless: every Xth confirmed kill with the gun in hand refills the magazine from reserve.
## True when it refilled.
static func count_kill(item: ItemInstance, instance: WeaponInstance, owner: bool) -> bool:
	var every: float = value(item, owner, &"bottomless")
	if every <= 0.0:
		return false
	instance.trait_kills += 1
	if instance.trait_kills < roundi(every):
		return false
	instance.trait_kills = 0
	instance.refill_magazine()
	return true


## Overpressure: the first shot after a reload fires more pellets. Every shot clears the charge.
static func take_pellets(item: ItemInstance, instance: WeaponInstance, owner: bool) -> int:
	var scale: float = value(item, owner, &"overpressure")
	var charged: bool = instance.charged
	instance.charged = false
	return roundi(instance.data.pellets * scale) if charged and scale > 0.0 else instance.data.pellets


## Dead Man's Hand: the shot that empties the magazine deals X times damage.
static func last_round_scale(item: ItemInstance, instance: WeaponInstance, owner: bool) -> float:
	var scale: float = value(item, owner, &"dead_mans_hand")
	return scale if scale > 0.0 and instance.ammo_in_mag == 0 else 1.0


## Cold Snap: true when this reload (from an empty magazine) should ask the server to freeze zombies.
static func wants_cold_snap(item: ItemInstance, owner: bool, empty: bool) -> bool:
	return empty and value(item, owner, &"cold_snap") > 0.0

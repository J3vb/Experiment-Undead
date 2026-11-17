## A gun on the wall. Buys the gun at its WeaponData cost, or refills its ammo
## for half that when the player already owns it (a fixed price once Reforged).
## Decides from the owner's facts about its guns; the gun or ammo is a grant.
class_name WallBuy
extends Interactable

@export var weapon: WeaponData
@export var reforged_ammo_cost: int = 4000


func get_prompt(player: Player) -> String:
	var owned: Weapon = _owned(player)
	if owned:
		return "Buy ammo for %s [F]  %d" % [owned.data.display_name, ammo_cost(owned.data.id)]
	return "Buy %s [F]  %d" % [weapon.display_name, weapon.cost]


func ammo_cost(owned_id: StringName) -> int:
	return int(weapon.cost * 0.5) if owned_id == weapon.id else reforged_ammo_cost


func interact(player: Player, facts: Dictionary = {}) -> void:
	if facts.is_empty():
		facts = owner_facts(player)
	var owned: StringName = facts.owned
	if owned == &"":
		if _pay(player, weapon.cost):
			_grant(player, InteractionSync.Grant.GIVE, weapon, &"", facts.slot)
	elif not facts.full and _pay(player, ammo_cost(owned)):
		_grant(player, InteractionSync.Grant.REFILL, weapon, owned, facts.slot)


## owned: held id of this gun or its Reforged tier (or empty); slot: that gun, or the gun in hand.
func owner_facts(player: Player) -> Dictionary:
	var owned: Weapon = _owned(player)
	var holder: WeaponHolder = player.weapons
	return {
		"owned": owned.data.id if owned else &"",
		"slot": holder.weapons.find(owned if owned else holder.current),
		"full": owned != null and owned.instance.ammo_reserve >= owned.data.max_reserve,
	}


func check_facts(facts: Dictionary) -> bool:
	if not (facts.get("owned") is StringName and facts.get("slot") is int and facts.get("full") is bool):
		return false
	var owned: StringName = facts.owned
	return owned == &"" or owned == weapon.id or (weapon.upgraded != null and owned == weapon.upgraded.id)


func _owned(player: Player) -> Weapon:
	for owned: Weapon in player.weapons.weapons:
		if owned.data.id == weapon.id or (weapon.upgraded != null and owned.data.id == weapon.upgraded.id):
			return owned
	return null

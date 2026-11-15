## A gun on the wall. Buys the gun at its WeaponData cost, or refills its ammo
## for half that when the player already owns it (a fixed price once Reforged).
class_name WallBuy
extends Interactable

@export var weapon: WeaponData
@export var reforged_ammo_cost: int = 4000


func get_prompt(player: Player) -> String:
	var owned: Weapon = _owned(player)
	if owned:
		return "Buy ammo for %s [F]  %d" % [owned.data.display_name, ammo_cost(owned)]
	return "Buy %s [F]  %d" % [weapon.display_name, weapon.cost]


func ammo_cost(owned: Weapon) -> int:
	return int(weapon.cost * 0.5) if owned.data.id == weapon.id else reforged_ammo_cost


func interact(player: Player) -> void:
	var owned: Weapon = _owned(player)
	if owned == null:
		if _pay(player, weapon.cost):
			player.weapons.give(weapon)
		return
	var full: bool = owned.instance.ammo_reserve >= owned.data.max_reserve
	if not full and _pay(player, ammo_cost(owned)):
		owned.instance.refill_all()
		owned.ammo_changed.emit(owned.instance.ammo_in_mag, owned.instance.ammo_reserve)


func _owned(player: Player) -> Weapon:
	for owned: Weapon in player.weapons.weapons:
		if owned.data.id == weapon.id or (weapon.upgraded != null and owned.data.id == weapon.upgraded.id):
			return owned
	return null

## A gun on the wall. Buys the gun at its WeaponData cost, or refills its ammo
## for half that when the player already owns it.
class_name WallBuy
extends Interactable

@export var weapon: WeaponData


func get_prompt(player: Player) -> String:
	if _owned(player):
		return "Buy ammo for %s [F]  %d" % [weapon.display_name, ammo_cost()]
	return "Buy %s [F]  %d" % [weapon.display_name, weapon.cost]


func ammo_cost() -> int:
	return int(weapon.cost * 0.5)


func interact(player: Player) -> void:
	var owned: Weapon = _owned(player)
	if owned == null:
		if _pay(player, weapon.cost):
			player.weapons.give(weapon)
		return
	var full: bool = owned.instance.ammo_reserve >= weapon.max_reserve
	if not full and _pay(player, ammo_cost()):
		owned.instance.refill_all()
		owned.ammo_changed.emit(owned.instance.ammo_in_mag, owned.instance.ammo_reserve)


func _owned(player: Player) -> Weapon:
	for owned: Weapon in player.weapons.weapons:
		if owned.instance.data == weapon:
			return owned
	return null

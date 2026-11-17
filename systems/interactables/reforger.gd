## Reforges the gun in hand into its upgraded WeaponData (full ammo). A gun
## with no further tier gets a full ammo refill instead. Needs power.
class_name Reforger
extends Interactable

@export var reforge_cost: int = 5000
@export var refill_cost: int = 2500


func _ready() -> void:
	super()
	add_to_group(&"reforger")
	_level().power_turned_on.connect(func() -> void: ($Glow as Node3D).visible = true)


func get_prompt(player: Player) -> String:
	if not _level().power_on:
		return "Needs power"
	var weapon: Weapon = player.weapons.current
	if weapon == null:
		return ""
	if weapon.data.upgraded:
		return "Reforge %s [F]  %d" % [weapon.data.display_name, reforge_cost]
	if _is_full(weapon):
		return ""
	return "Refill %s [F]  %d" % [weapon.data.display_name, refill_cost]


func interact(player: Player, _facts: Dictionary = {}) -> void:
	var weapon: Weapon = player.weapons.current
	if not _level().power_on or weapon == null:
		return
	if weapon.data.upgraded:
		if _pay(player, reforge_cost):
			player.weapons.replace_current(weapon.data.upgraded)
	elif not _is_full(weapon) and _pay(player, refill_cost):
		weapon.instance.refill_all()
		weapon.ammo_changed.emit(weapon.instance.ammo_in_mag, weapon.instance.ammo_reserve)


func _is_full(weapon: Weapon) -> bool:
	var ammo: WeaponInstance = weapon.instance
	return ammo.ammo_in_mag == weapon.data.magazine_size and ammo.ammo_reserve == weapon.data.max_reserve

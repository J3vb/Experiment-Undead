## Reforges the gun in hand into its upgraded WeaponData (full ammo). A gun
## with no further tier gets a full ammo refill instead. Needs power.
## Decides from the owner's facts; the next tier comes from the server's data.
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


func interact(player: Player, facts: Dictionary = {}) -> void:
	if facts.is_empty():
		facts = owner_facts(player)
	var id: StringName = facts.current
	if not _level().power_on or id == &"":
		return
	var data: WeaponData = Content.weapon(id)
	if data.upgraded:
		if _pay(player, reforge_cost):
			_grant(player, InteractionSync.Grant.UPGRADE, data.upgraded, id, facts.slot)
	elif not facts.full and _pay(player, refill_cost):
		_grant(player, InteractionSync.Grant.REFILL, data, id, facts.slot)


## current: id of the gun in hand (or empty); slot: its index; full: no ammo to refill.
func owner_facts(player: Player) -> Dictionary:
	var held: Weapon = player.weapons.current
	if held == null:
		return {"current": &"", "slot": -1, "full": true}
	return {"current": held.data.id, "slot": player.weapons.weapons.find(held), "full": _is_full(held)}


func check_facts(facts: Dictionary) -> bool:
	if not (facts.get("current") is StringName and facts.get("slot") is int and facts.get("full") is bool):
		return false
	return facts.current == &"" or Content.ids(&"weapons").has(facts.current)


func _is_full(weapon: Weapon) -> bool:
	var ammo: WeaponInstance = weapon.instance
	return ammo.ammo_in_mag == weapon.data.magazine_size and ammo.ammo_reserve == weapon.data.max_reserve

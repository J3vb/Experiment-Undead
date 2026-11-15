## Both-barrel trigger and shot impulse for guns tagged double. Shares Weapon's
## normal cooldown, reload, pellet traces and multiplayer hit path.
class_name DoubleBarrel
extends Node

const KNOCKBACK_SPEED: float = 8.0
const ALT_FIRE: int = InputFrame.ALT_FIRE

var weapon: Weapon
var _held: bool = false
var _requested: bool = false
var _both: bool = false


static func attach_to(owner_weapon: Weapon) -> DoubleBarrel:
	if not owner_weapon.data.loot_tags.has(&"double"):
		return null
	var component: DoubleBarrel = DoubleBarrel.new()
	component.weapon = owner_weapon
	owner_weapon.add_child(component)
	return component


static func consume_rounds(owner_weapon: Weapon, component: DoubleBarrel) -> int:
	var rounds: int = component.rounds_for_shot() if component else 1
	owner_weapon.instance.ammo_in_mag -= rounds
	return rounds


func buffer(remaining: float) -> float:
	var held: bool = weapon.shooter != null and weapon.shooter.input_enabled and weapon.shooter.last_frame.has(ALT_FIRE)
	var just_pressed: bool = held and not _held
	_held = held
	if just_pressed:
		_requested = true
		remaining = Weapon.BUFFER_TIME
	elif remaining <= 0.0 or (weapon.trigger_held and not weapon._trigger_was_held):
		_requested = false
	return remaining


func rounds_for_shot() -> int:
	_both = _requested and weapon.instance.ammo_in_mag >= 2
	_requested = false
	return weapon.instance.ammo_in_mag if _both else 1


func impulse(direction: Vector3) -> Vector3:
	return direction * (KNOCKBACK_SPEED if _both else 2.0)

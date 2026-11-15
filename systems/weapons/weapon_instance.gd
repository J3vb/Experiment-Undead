## Live state of one gun a player owns. WeaponData stays untouched.
class_name WeaponInstance
extends RefCounted

var data: WeaponData
var ammo_in_mag: int = 0
var ammo_reserve: int = 0


func _init(p_data: WeaponData) -> void:
	data = p_data
	ammo_in_mag = data.magazine_size
	ammo_reserve = data.starting_reserve


func needs_reload() -> bool:
	return ammo_in_mag < data.magazine_size and ammo_reserve > 0


## Moves bullets from reserve into the magazine. Returns how many moved.
func refill_magazine() -> int:
	var taken: int = mini(data.magazine_size - ammo_in_mag, ammo_reserve)
	ammo_in_mag += taken
	ammo_reserve -= taken
	return taken


func add_reserve(amount: int) -> void:
	ammo_reserve = mini(ammo_reserve + amount, data.max_reserve)


func refill_all() -> void:
	ammo_in_mag = data.magazine_size
	ammo_reserve = data.max_reserve

## Turns the map's power on (free, once). Power doors and machines listen to
## Level.power_turned_on.
class_name PowerSwitch
extends Interactable


func get_prompt(_player: Player) -> String:
	return "" if _level().power_on else "Turn on power [F]"


func interact(_player: Player) -> void:
	if _level().power_on:
		return
	_level().turn_power_on()
	($PowerSound as AudioStreamPlayer3D).play()

## Turns the map's power on (free, once). Power doors and machines listen to
## Level.power_turned_on. The sound plays on every peer when the level's power comes on.
class_name PowerSwitch
extends Interactable


func _ready() -> void:
	super()
	_level().power_turned_on.connect(($PowerSound as AudioStreamPlayer3D).play)


func get_prompt(_player: Player) -> String:
	return "" if _level().power_on else "Turn on power [F]"


func interact(_player: Player, _facts: Dictionary = {}) -> void:
	_level().turn_power_on()

## Sells one Serum. Needs power. A player can hold each Serum once per run.
class_name MedDispenser
extends Interactable

@export var serum: SerumData


func _ready() -> void:
	super()
	add_to_group(&"med_dispenser")
	($Label as Label3D).text = serum.display_name
	_level().power_turned_on.connect(_light_up)


func get_prompt(player: Player) -> String:
	if not _level().power_on:
		return "Needs power"
	if player.serums.has(serum):
		return ""
	return "Buy %s [F]  %d" % [serum.display_name, serum.cost]


func interact(player: Player) -> void:
	if not _level().power_on or player.serums.has(serum):
		return
	if _pay(player, serum.cost):
		player.add_serum(serum)


func _light_up() -> void:
	($Glow as Node3D).visible = true
	($GlowBack as Node3D).visible = true

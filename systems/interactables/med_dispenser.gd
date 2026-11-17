## Sells one Serum. Needs power. A player can hold each Serum once per run.
## Sales reach clients; a sold-out dispenser retires on every peer.
class_name MedDispenser
extends Interactable

@export var serum: SerumData
## After this many sales in a run the dispenser is gone. 0 = no limit.
@export var max_sales: int = 0

var sales: int = 0


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


func interact(player: Player, _facts: Dictionary = {}) -> void:
	if not _level().power_on or player.serums.has(serum):
		return
	if _pay(player, serum.cost):
		player.add_serum(serum)
		sales += 1
		if sales == max_sales:
			var sound: AudioStreamPlayer3D = $BuySound
			sound.stop()
			sound.reparent(_level())
			sound.finished.connect(sound.queue_free)
			sound.play()
			retire()
		else:
			state_changed.emit()


func accepts_requests() -> bool:
	return true


func net_state() -> Dictionary:
	return {"sales": sales}


func apply_net_state(state: Dictionary) -> void:
	sales = state.get("sales", sales)


func _light_up() -> void:
	($Glow as Node3D).visible = true
	($GlowBack as Node3D).visible = true

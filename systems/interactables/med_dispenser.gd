## Sells one Serum. Needs power. A player can hold each Serum once per run.
## Sales reach clients; a sold-out dispenser retires on every peer.
class_name MedDispenser
extends Interactable

@export var serum: SerumData
## After this many sales in a run the dispenser is gone. 0 = no limit.
@export var max_sales: int = 0

var sales: int = 0
## This peer played a buy chime here, so it must outlive the sold-out dispenser.
var _chimed: bool = false


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
			retire()
		else:
			state_changed.emit()


func play_result(paid: bool) -> void:
	super(paid)
	_chimed = _chimed or paid


## Sold out. The buyer's chime keeps playing after the dispenser is gone, also on a client.
func retire() -> void:
	if _chimed:
		var sound: AudioStreamPlayer3D = $BuySound
		sound.stop()
		sound.reparent(_level())
		sound.finished.connect(sound.queue_free)
		sound.play()
	super()


func accepts_requests() -> bool:
	return true


func net_state() -> Dictionary:
	return {"sales": sales}


func apply_net_state(state: Dictionary) -> void:
	sales = state.get("sales", sales)


func _light_up() -> void:
	($Glow as Node3D).visible = true
	($GlowBack as Node3D).visible = true

## Buyable door or debris. Buying it removes the door (and its blocker child),
## opens its area so that area's spawn points join, and rebakes the navmesh.
## Doors that open the same area open together. A door with cost 0 that needs
## power opens by itself when the power comes on. Clients open doors the
## server lists as removed; only the server rebakes.
class_name Door
extends Interactable

@export var opens_area: StringName
@export var cost: int = 1000
@export var needs_power: bool = false
@export var label: String = "door"

var is_open: bool = false
var level: Level


func _ready() -> void:
	super()
	add_to_group(&"doors")
	level = _level()
	if needs_power and cost == 0:
		level.power_turned_on.connect(open)


func get_prompt(_player: Player) -> String:
	if is_open or cost == 0:
		return "Needs power" if needs_power and not level.power_on else ""
	if needs_power and not level.power_on:
		return "Needs power"
	return "Open %s [F]  %d" % [label, cost]


func interact(player: Player, _facts: Dictionary = {}) -> void:
	if is_open or cost == 0 or (needs_power and not level.power_on):
		return
	if _pay(player, cost):
		open()


func accepts_requests() -> bool:
	return true


## A client told by the server that this door is gone plays the opening too.
func retire() -> void:
	if is_open:
		super()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	var sound: AudioStreamPlayer3D = $OpenSound
	sound.reparent(level)
	sound.finished.connect(sound.queue_free)
	sound.play()
	var buy: AudioStreamPlayer3D = $BuySound
	if buy.playing:
		buy.stop()
		buy.reparent(level)
		buy.finished.connect(buy.queue_free)
		buy.play()
	# Free the blocker now so the navmesh rebake no longer sees it.
	get_node("Blocker").free()
	retire()
	var others: Array[Node] = get_tree().get_nodes_in_group(&"doors")
	for node: Node in others:
		var other: Door = node as Door
		if other != self and other.opens_area == opens_area:
			other.open()
	level.open_area(opens_area)
	if multiplayer.is_server():
		level.rebake_navigation()

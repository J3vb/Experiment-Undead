## The Halcyon Labs secret "Signal in the Static": its child WallRadios get the
## three tones in a random order at power-on (session RNG, server only). Pressing
## them from lowest to highest lights each one; a wrong press resets them all.
## The last right press opens the freezer door to the Cold Room.
class_name RadioPuzzle
extends Node3D

@export var door: Door

var radios: Array[WallRadio] = []


func _ready() -> void:
	for child: Node in get_children():
		var radio: WallRadio = child as WallRadio
		if radio:
			radios.append(radio)
			radio.pressed.connect(_on_pressed)
	var level: Level = get_parent() as Level
	level.power_turned_on.connect(_roll)


func is_solved() -> bool:
	return door == null or door.is_open


func _roll() -> void:
	var level: Level = get_parent() as Level
	var session: GameSession = level.get_parent() as GameSession
	if session == null or not multiplayer.is_server():
		return
	var rng: RandomNumberGenerator = session.rng
	var ranks: Array[int] = []
	for i: int in radios.size():
		ranks.insert(rng.randi_range(0, i), i)
	for i: int in radios.size():
		radios[i].set_pitch(ranks[i])


func _on_pressed(radio: WallRadio) -> void:
	if is_solved():
		return
	var next: int = radios.filter(func(r: WallRadio) -> bool: return r.lit).size()
	var right: bool = radio.pitch == next
	radio.answer(right)
	if not right:
		for other: WallRadio in radios:
			other.reset(other == radio)
	elif next + 1 == radios.size():
		door.open()

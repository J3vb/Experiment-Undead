## The exfil hatch. From round 10 it opens every 5th round, for that round.
## A player calls the exfil with the interact key; once living players have
## stood within HOLD_RADIUS of it for HOLD_TIME seconds in total, the squad
## leaves and the match ends with the exfil bonus.
class_name ExfilHatch
extends Interactable

const FIRST_ROUND: int = 10
const EVERY_ROUNDS: int = 5
const HOLD_TIME: float = 60.0
const HOLD_RADIUS: float = 4.0

var is_open: bool = false
var is_holding: bool = false
var hold_left: float = HOLD_TIME


func _ready() -> void:
	super()
	add_to_group(&"exfil")
	Events.round_started.connect(_on_round_started)
	Events.round_ended.connect(_on_round_ended)
	set_physics_process(false)


func get_prompt(_player: Player) -> String:
	return "Call exfil [F]" if is_open and not is_holding else ""


func interact(_player: Player) -> void:
	if not is_open or is_holding:
		return
	is_holding = true
	hold_left = HOLD_TIME
	set_physics_process(true)
	Events.exfil_called.emit(self)


func has_player_in_zone() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if player.is_alive() and player.global_position.distance_to(global_position) <= HOLD_RADIUS:
			return true
	return false


func _physics_process(delta: float) -> void:
	if not Net.is_authority() or not has_player_in_zone():
		return
	hold_left -= delta
	if hold_left > 0.0:
		return
	set_physics_process(false)
	is_holding = false
	_set_open(false)
	(get_tree().get_first_node_in_group(&"game_session") as GameSession).finish_exfil()


func _set_open(value: bool) -> void:
	is_open = value
	($Glow as Node3D).visible = value


func _on_round_started(round_number: int, _count: int) -> void:
	if round_number >= FIRST_ROUND and round_number % EVERY_ROUNDS == 0:
		_set_open(true)
		Events.exfil_opened.emit()


func _on_round_ended(_round_number: int) -> void:
	if not is_holding:
		_set_open(false)

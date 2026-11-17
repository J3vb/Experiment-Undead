## The exfil hatch. From round 10 it opens every 5th round, for that round.
## A player calls the exfil with the interact key; once living players have
## stood within HOLD_RADIUS of it for HOLD_TIME seconds in total, the squad
## leaves and the match ends with the exfil bonus. The server owns the hold;
## clients get open, holding and counting and run their own countdown.
class_name ExfilHatch
extends Interactable

const FIRST_ROUND: int = 10
const EVERY_ROUNDS: int = 5
const HOLD_TIME: float = 60.0
const HOLD_RADIUS: float = 4.0

var is_open: bool = false
var is_holding: bool = false
var hold_left: float = HOLD_TIME
## True while a living player is in the zone, so the hold counts down.
var is_counting: bool = false


func _ready() -> void:
	super()
	add_to_group(&"exfil")
	Events.round_started.connect(_on_round_started)
	Events.round_ended.connect(_on_round_ended)
	set_physics_process(false)


func get_prompt(_player: Player) -> String:
	return "Call exfil [F]" if is_open and not is_holding else ""


func interact(_player: Player, _facts: Dictionary = {}) -> void:
	if not is_open or is_holding:
		return
	is_holding = true
	hold_left = HOLD_TIME
	set_physics_process(true)
	state_changed.emit()
	Events.exfil_called.emit(self)


func has_player_in_zone() -> bool:
	var level: Level = _level()
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if (
			player.is_alive()
			and (level == null or level.is_ancestor_of(player))
			and player.global_position.distance_to(global_position) <= HOLD_RADIUS
		):
			return true
	return false


func net_state() -> Dictionary:
	return {"open": is_open, "holding": is_holding, "hold_left": hold_left, "counting": is_counting}


## Client side: glow, countdown and the HUD events when the server's state changes.
func apply_net_state(state: Dictionary) -> void:
	var was_open: bool = is_open
	var was_holding: bool = is_holding
	_set_open(state.get("open", false))
	is_holding = state.get("holding", false)
	hold_left = state.get("hold_left", HOLD_TIME)
	is_counting = state.get("counting", false)
	if is_open and not was_open:
		Events.exfil_opened.emit()
	if is_holding and not was_holding:
		Events.exfil_called.emit(self)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var counting: bool = has_player_in_zone()
	if counting != is_counting:
		is_counting = counting
		state_changed.emit()
	if not counting:
		return
	hold_left -= delta
	if hold_left > 0.0:
		return
	set_physics_process(false)
	is_holding = false
	is_counting = false
	_set_open(false)
	(get_tree().get_first_node_in_group(&"game_session") as GameSession).finish_exfil()


## Visual only: the client's countdown between server updates.
func _process(delta: float) -> void:
	if is_counting and not multiplayer.is_server():
		hold_left = maxf(hold_left - delta, 0.0)


func _set_open(value: bool) -> void:
	is_open = value
	($Glow as Node3D).visible = value
	state_changed.emit()


func _on_round_started(round_number: int, _count: int) -> void:
	if multiplayer.is_server() and round_number >= FIRST_ROUND and round_number % EVERY_ROUNDS == 0:
		_set_open(true)
		Events.exfil_opened.emit()


func _on_round_ended(_round_number: int) -> void:
	if multiplayer.is_server() and not is_holding:
		_set_open(false)

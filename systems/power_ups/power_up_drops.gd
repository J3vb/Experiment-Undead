## Rolls a power-up drop for every zombie kill: drop_chance each, at most
## max_per_round a round. Types come from a shuffled deck, so every type drops
## once before any repeats. Lives in the GameSession.
class_name PowerUpDrops
extends Node

const SCENE: PackedScene = preload("res://systems/power_ups/power_up.tscn")

@export var drop_chance: float = 0.025
@export var max_per_round: int = 4
@export var power_ups: Array[PowerUpData] = []

var session: GameSession
var dropped_this_round: int = 0
var _deck: Array[PowerUpData] = []


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.round_started.connect(func(_round: int, _count: int) -> void: dropped_this_round = 0)


func drop(data: PowerUpData, at: Vector3) -> PowerUp:
	dropped_this_round += 1
	var pickup: PowerUp = SCENE.instantiate() as PowerUp
	pickup.data = data
	session.level.add_child(pickup)
	pickup.global_position = at + Vector3.UP * 0.8
	return pickup


func _on_enemy_killed(enemy: Node3D, _info: DamageInfo) -> void:
	if not Net.is_authority() or dropped_this_round >= max_per_round or power_ups.is_empty():
		return
	if session.rng.randf() < drop_chance:
		drop(_next(), enemy.global_position)


func _next() -> PowerUpData:
	if _deck.is_empty():
		_deck = power_ups.duplicate()
		for i: int in range(_deck.size() - 1, 0, -1):
			var j: int = session.rng.randi_range(0, i)
			var swap: PowerUpData = _deck[i]
			_deck[i] = _deck[j]
			_deck[j] = swap
	return _deck.pop_back()

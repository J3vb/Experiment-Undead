## Owns each player's run XP and starting total, and announces newly reached levels.
class_name ProgressionService
extends Node

signal xp_gained(player: Player, amount: int, total: int)

@export var rules: XpRules = preload("res://content/progression/xp_rules.tres")

var _xp: Dictionary[Player, int] = {}
var _start_total: Dictionary[Player, int] = {}


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.round_ended.connect(_on_round_ended)


func add_xp(player: Player, amount: int) -> void:
	if not Net.is_authority() or amount <= 0:
		return
	var previous_level: int = get_level(player)
	_xp[player] = _xp.get(player, 0) + amount
	var new_level: int = get_level(player)
	xp_gained.emit(player, amount, _xp[player])
	for level: int in range(previous_level + 1, new_level + 1):
		Events.player_leveled_up.emit(player, level)


func get_xp(player: Player) -> int:
	return _xp.get(player, 0)


func set_start_total(player: Player, total: int) -> void:
	if not Net.is_authority():
		return
	_start_total[player] = maxi(total, 0)


func get_total_xp(player: Player) -> int:
	return _start_total.get(player, 0) + get_xp(player)


func get_level(player: Player) -> int:
	return rules.level_for_total_xp(get_total_xp(player))


func _on_enemy_killed(enemy: Node3D, info: DamageInfo) -> void:
	var player: Player = info.attacker as Player
	var zombie: Zombie = enemy as Zombie
	if player and zombie and zombie.data:
		var amount: int = zombie.data.xp_reward
		if info.is_headshot():
			amount += rules.headshot_kill_bonus
		add_xp(player, amount)


func _on_round_ended(round_number: int) -> void:
	if not Net.is_authority():
		return
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if player and player.is_alive():
			add_xp(player, rules.round_clear_xp_per_round * round_number)

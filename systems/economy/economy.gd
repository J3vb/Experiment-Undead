## Pays players for hits and kills and is the only way to spend points.
## Lives in the GameSession.
class_name Economy
extends Node

@export var rules: EconomyRules

var _repair_points: Dictionary[Player, int] = {}


func _ready() -> void:
	Events.player_spawned.connect(_on_player_spawned)
	Events.enemy_damaged.connect(_on_enemy_damaged)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.round_ended.connect(_on_round_ended)


func try_spend(player: Player, cost: int) -> bool:
	if player.wallet.points < cost:
		return false
	player.wallet.add(-cost)
	return true


## Pays a barrier repair, up to the per-round cap.
func pay_repair(player: Player) -> void:
	var earned: int = _repair_points.get(player, 0)
	var amount: int = mini(rules.points_per_plank, rules.max_repair_points_per_round - earned)
	if amount <= 0:
		return
	_repair_points[player] = earned + amount
	player.wallet.add(amount)


func _on_player_spawned(player: Player) -> void:
	player.wallet.set_points(rules.starting_points)


func _on_enemy_damaged(_enemy: Node3D, info: DamageInfo) -> void:
	var player: Player = info.attacker as Player
	if player:
		player.wallet.add(rules.points_per_hit)


func _on_enemy_killed(_enemy: Node3D, info: DamageInfo) -> void:
	var player: Player = info.attacker as Player
	if player == null:
		return
	var amount: int = rules.points_per_kill
	if info.is_headshot():
		amount += rules.headshot_kill_bonus
	elif info.damage_type == DamageInfo.Type.MELEE:
		amount += rules.melee_kill_bonus
	player.wallet.add(amount)


func _on_round_ended(_round_number: int) -> void:
	_repair_points.clear()
	if rules.round_clear_bonus <= 0:
		return
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		(node as Player).wallet.add(rules.round_clear_bonus)

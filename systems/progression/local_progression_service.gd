## In-memory progression for solo play. Tracks XP per player for the match.
## Levels, skills and loot build on this later.
class_name LocalProgressionService
extends ProgressionService

var _xp: Dictionary[Player, int] = {}

func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)

func add_xp(player: Player, amount: int) -> void:
	if not Net.is_authority() or amount <= 0:
		return
	_xp[player] = _xp.get(player, 0) + amount
	xp_gained.emit(player, amount, _xp[player])

func get_xp(player: Player) -> int:
	return _xp.get(player, 0)

func _on_enemy_killed(enemy: Node3D, info: DamageInfo) -> void:
	var player: Player = info.attacker as Player
	var zombie: Zombie = enemy as Zombie
	if player and zombie and zombie.data:
		add_xp(player, zombie.data.xp_reward)

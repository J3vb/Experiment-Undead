## Interface for XP, levels and items. Today it is local and in memory;
## later a server-backed version replaces it without touching callers.
class_name ProgressionService
extends Node

signal xp_gained(player: Player, amount: int, total: int)

func add_xp(_player: Player, _amount: int) -> void:
	pass

func get_xp(_player: Player) -> int:
	return 0

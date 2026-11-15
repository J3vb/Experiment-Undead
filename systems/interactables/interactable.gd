## Something a player uses with the interact key: a door, a wall-buy, a switch.
## An Area3D on the interactable layer; the player looks at it and presses
## interact. Subclasses override get_prompt() and interact().
class_name Interactable
extends Area3D


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	monitoring = false


## HUD text while a player looks at this. Empty when there is nothing to do.
func get_prompt(_player: Player) -> String:
	return ""


## Only called where Net.is_authority() is true.
func interact(_player: Player) -> void:
	pass


func _pay(player: Player, amount: int) -> bool:
	var session: GameSession = get_tree().get_first_node_in_group(&"game_session") as GameSession
	var paid: bool = session != null and session.economy.try_spend(player, amount)
	if paid:
		($BuySound as AudioStreamPlayer3D).play()
	else:
		($DeniedSound as AudioStreamPlayer3D).play()
	return paid


func _level() -> Level:
	var node: Node = get_parent()
	while node and not node is Level:
		node = node.get_parent()
	return node as Level

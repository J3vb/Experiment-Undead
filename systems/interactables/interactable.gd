## Something a player uses with the interact key: a door, a wall-buy, a switch.
## An Area3D on the interactable layer; the player looks at it and presses
## interact. Subclasses override get_prompt() and interact(). In co-op a client
## asks InteractionSync, and the server runs the same interact().
class_name Interactable
extends Area3D

## Server only: net_state() changed, so every client needs the new state.
signal state_changed
## This interactable is leaving the map for good (opened door, sold out).
signal retired


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	monitoring = false


## HUD text while a player looks at this. Empty when there is nothing to do.
func get_prompt(_player: Player) -> String:
	return ""


## Only called where Net.is_authority() is true, or on a client for is_local() types.
## facts: what only the owning client knows about its own guns (owner_facts()).
func interact(_player: Player, _facts: Dictionary = {}) -> void:
	pass


## True for personal things the client handles alone (its own loot).
func is_local() -> bool:
	return false


## False until this type's state and grants reach clients; the server refuses client requests.
func accepts_requests() -> bool:
	return false


## Sent with a client's request: facts about the client's own guns.
func owner_facts(_player: Player) -> Dictionary:
	return {}


## State every client must see. Empty means nothing to sync.
func net_state() -> Dictionary:
	return {}


func apply_net_state(_state: Dictionary) -> void:
	pass


## Leaves the map on every peer. Types with a leaving effect override this.
func retire() -> void:
	retired.emit()
	queue_free()


func play_result(paid: bool) -> void:
	(get_node(^"BuySound" if paid else ^"DeniedSound") as AudioStreamPlayer3D).play()


func _pay(player: Player, amount: int) -> bool:
	var session: GameSession = player.session
	var paid: bool = session != null and session.economy.try_spend(player, amount)
	if session and session.interactions and player.net_id != multiplayer.get_unique_id():
		session.interactions.send_result(player, self, paid)
	else:
		play_result(paid)
	return paid


func _level() -> Level:
	var node: Node = get_parent()
	while node and not node is Level:
		node = node.get_parent()
	return node as Level

## Runs the real banking path without loading a map or opening another network connection.
extends GameSession


func _ready() -> void:
	loot = LootService.new()
	loot.name = "LootService"
	loot.session = self
	add_child(loot)
	match_end = MatchEnd.new()
	match_end.session = self
	add_child(match_end)


func _exit_tree() -> void:
	pass


func get_players() -> Array[Player]:
	var out: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if player and player.multiplayer == multiplayer:
			out.append(player)
	return out

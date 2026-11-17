## Burning wreckage beside the Loading Dock truck gaps: decoration only (no
## collision, not in the navmesh), shown while fewer than COOP_PLAYERS players
## are in the match. The gaps' co-op spawn points switch on at the same count.
class_name CoopWreckage
extends Node3D

## Maps doc: co-op-only spawn points and rules start at 3 players.
const COOP_PLAYERS: int = 3


func _ready() -> void:
	Events.player_spawned.connect(_watch)
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		_watch(node)
	refresh()


func refresh() -> void:
	if is_inside_tree():
		visible = get_tree().get_nodes_in_group(&"players").size() < COOP_PLAYERS


func _watch(player: Node) -> void:
	if not player.tree_exited.is_connected(refresh):
		player.tree_exited.connect(refresh)
	refresh()

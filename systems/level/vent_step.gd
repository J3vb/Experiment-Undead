## The climb back up into the Containment vent from the Mess Hall: a short ramp
## under the ledge that is there (with collision) only while COOP_PLAYERS or
## more players are in the match. Below that the vent is a one-way drop.
class_name VentStep
extends Node3D

## Maps doc: the reverse climb works with 3 or more players.
const COOP_PLAYERS: int = 3


func _ready() -> void:
	Events.player_spawned.connect(_watch)
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		_watch(node)
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	var on: bool = get_tree().get_nodes_in_group(&"players").size() >= COOP_PLAYERS
	visible = on
	for node: Node in find_children("*", "CollisionObject3D", true, false):
		(node as CollisionObject3D).collision_layer = Layers.WORLD if on else 0


func _watch(player: Node) -> void:
	if not player.tree_exited.is_connected(refresh):
		player.tree_exited.connect(refresh)
	refresh()

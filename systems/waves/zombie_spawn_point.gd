## A fixed zombie entry point (window, vent or grate) that belongs to one map
## area. The Level puts it in the Spawner's group once its area is open.
## A window point has a Barrier the zombie must break through first. Co-op-only
## points (min_players 3) are used only with that many players in the match.
class_name ZombieSpawnPoint
extends Marker3D

@export var area: StringName
@export var barrier: Barrier
@export var min_players: int = 1

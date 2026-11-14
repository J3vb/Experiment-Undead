## A fixed zombie entry point (window, vent or grate) that belongs to one map
## area. The Level puts it in the Spawner's group once its area is open.
class_name ZombieSpawnPoint
extends Marker3D

@export var area: StringName

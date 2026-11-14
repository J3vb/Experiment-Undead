## Root script for a playable map. Bakes navigation at load (so grey-box
## edits never leave a stale navmesh) and exposes the player spawn.
class_name Level
extends Node3D

signal navigation_ready

@export var navigation_region: NavigationRegion3D
@export var player_spawn: Marker3D

var is_navigation_ready: bool = false

func _ready() -> void:
	if navigation_region == null:
		_finish()
		return
	navigation_region.bake_finished.connect(_on_baked, CONNECT_ONE_SHOT)
	navigation_region.bake_navigation_mesh(false)

func get_player_spawn() -> Transform3D:
	return player_spawn.global_transform if player_spawn else Transform3D.IDENTITY

func _on_baked() -> void:
	# The new mesh is usable only after the navigation map syncs.
	NavigationServer3D.map_changed.connect(_on_map_changed)

func _on_map_changed(map: RID) -> void:
	if map != get_world_3d().navigation_map:
		return
	NavigationServer3D.map_changed.disconnect(_on_map_changed)
	_finish()

func _finish() -> void:
	is_navigation_ready = true
	navigation_ready.emit()

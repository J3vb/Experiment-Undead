## Root script for a playable map. Bakes navigation at load (so grey-box
## edits never leave a stale navmesh), exposes the player spawn and tracks
## which areas are open (only spawn points in open areas are used) and
## whether the power is on.
class_name Level
extends Node3D

## Emitted once the navigation map actually contains the baked mesh.
signal navigation_ready
signal power_turned_on

@export var navigation_region: NavigationRegion3D
@export var player_spawn: Marker3D
@export var start_area: StringName

var is_navigation_ready: bool = false
var open_areas: Array[StringName] = []
var power_on: bool = false
var _baked: bool = false
var _rebake_pending: bool = false


func _ready() -> void:
	if start_area != &"":
		open_area(start_area)
	if navigation_region == null:
		_finish()
		return
	navigation_region.bake_finished.connect(func() -> void: _baked = true, CONNECT_ONE_SHOT)
	navigation_region.bake_navigation_mesh(false)


func turn_power_on() -> void:
	if power_on:
		return
	power_on = true
	power_turned_on.emit()


## Bakes again at the end of this frame (after a door opened). Several calls in
## one frame give one bake. On the main thread: threaded bakes never finished
## on the 2-core CI runner, and a door purchase is rare enough for one short hitch.
func rebake_navigation() -> void:
	if not _rebake_pending:
		_rebake_pending = true
		_rebake_now.call_deferred()


func is_rebaking() -> bool:
	return _rebake_pending


func _rebake_now() -> void:
	_rebake_pending = false
	navigation_region.bake_navigation_mesh(false)


func open_area(area: StringName) -> void:
	if open_areas.has(area):
		return
	open_areas.append(area)
	for node: Node in find_children("*", "Marker3D"):
		var point: ZombieSpawnPoint = node as ZombieSpawnPoint
		if point and point.area == area:
			point.add_to_group(&"enemy_spawn")


func get_player_spawn() -> Transform3D:
	return player_spawn.global_transform if player_spawn else Transform3D.IDENTITY


func _physics_process(_delta: float) -> void:
	if is_navigation_ready or not _baked:
		return
	# The new mesh is usable only after the navigation map has synced it,
	# which can take one or more physics frames.
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	var probe: Vector3 = get_player_spawn().origin
	if NavigationServer3D.map_get_closest_point_owner(map, probe) == navigation_region.get_rid():
		_finish()


func _finish() -> void:
	is_navigation_ready = true
	set_physics_process(false)
	navigation_ready.emit()

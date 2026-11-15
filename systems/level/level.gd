## Root script for a playable map. Bakes navigation at load (so grey-box
## edits never leave a stale navmesh), exposes the player spawn and tracks
## which areas are open (only spawn points in open areas are used) and
## whether the power is on.
class_name Level
extends Node3D

## Emitted once the navigation map actually contains the baked mesh.
signal navigation_ready
signal power_turned_on

## A navmesh bake slower than this is a visible hitch.
const NAV_BAKE_WARN_MS: float = 100.0
## Navigation not usable this long after load means the bake or sync failed.
const NAV_READY_WARN_MS: float = 10000.0

@export var navigation_region: NavigationRegion3D
@export var player_spawn: Marker3D
@export var start_area: StringName

var is_navigation_ready: bool = false
var open_areas: Array[StringName] = []
var power_on: bool = false
var _baked: bool = false
var _rebake_pending: bool = false
var _ready_usec: int = 0


func _ready() -> void:
	if start_area != &"":
		open_area(start_area)
	if navigation_region == null:
		_finish()
		return
	navigation_region.bake_finished.connect(func() -> void: _baked = true, CONNECT_ONE_SHOT)
	_ready_usec = Time.get_ticks_usec()
	_bake(&"load")


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
	_bake(&"rebake")


## Main-thread bake; the time is logged because it freezes the game.
func _bake(reason: StringName) -> void:
	var start: int = Time.get_ticks_usec()
	navigation_region.bake_navigation_mesh(false)
	var ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var data: Dictionary = {"reason": reason, "ms": snappedf(ms, 0.1), "open_areas": open_areas}
	if ms > NAV_BAKE_WARN_MS:
		Log.warn(&"level", &"navmesh_bake_slow", data)
	else:
		Log.info(&"level", &"navmesh_baked", data)


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
	if is_navigation_ready:
		return
	_warn_if_navigation_late()
	if not _baked:
		return
	# The new mesh is usable only after the navigation map has synced it,
	# which can take one or more physics frames.
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	var probe: Vector3 = get_player_spawn().origin
	if NavigationServer3D.map_get_closest_point_owner(map, probe) == navigation_region.get_rid():
		_finish()


func _warn_if_navigation_late() -> void:
	var waited_ms: float = (Time.get_ticks_usec() - _ready_usec) / 1000.0
	if _ready_usec != 0 and waited_ms > NAV_READY_WARN_MS:
		_ready_usec = 0
		Log.error(&"level", &"navigation_not_ready", {"waited_ms": int(waited_ms), "baked": _baked})


func _finish() -> void:
	if _ready_usec != 0:
		Log.info(&"level", &"navigation_ready", {"ms": (Time.get_ticks_usec() - _ready_usec) / 1000})
	_ready_usec = 0
	is_navigation_ready = true
	set_physics_process(false)
	navigation_ready.emit()

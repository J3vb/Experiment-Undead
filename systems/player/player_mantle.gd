## Auto mantle for one Player (docs/plans/mantle.md): a jump press while pushing
## forward into a ledge min_height to max_height above the floor you left climbs
## onto it. Pushing into one in the first JUMP_WINDOW seconds of a jump works too.
## Runs only where the Player simulates (its owner); PoseSync shows it to others.
class_name PlayerMantle
extends RefCounted

## Seconds after a jump press in which pushing into a ledge still mantles.
const JUMP_WINDOW: float = 0.3
## Share of the mantle spent rising; the rest moves onto the ledge.
const RISE_SHARE: float = 0.6
## Forward stick (move.y is negative forward) needed to mantle.
const PUSH: float = -0.5
## Leaving speed as a share of walk speed, so the climb flows into a walk.
const EXIT_SPEED: float = 0.5
const MARGIN: float = 0.02
const MIN_TOP_NORMAL: float = 0.7
## How far past the wall face the ledge top is probed and the player lands.
const PROBE_IN: float = 0.1
const WALL_MASK: int = Layers.WORLD | Layers.BARRIER
const ROOM_MASK: int = Layers.WORLD | Layers.BARRIER | Layers.ENEMY | Layers.PLAYER

var _window: float = 0.0
var _floor_y: float = 0.0
var _active: bool = false
var _time: float = 0.0
var _duration: float = 0.0
var _start: Vector3
var _top: Vector3
var _end: Vector3
var _forward: Vector3
var _shape_offset: Vector3
var _radius: float = 0.4
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _room: PhysicsShapeQueryParameters3D


func is_active() -> bool:
	return _active


func cancel() -> void:
	_active = false
	_window = 0.0


## One tick: may start a mantle, then moves an active one. True while mantling.
func update(player: Player, frame: InputFrame, delta: float) -> bool:
	if _active and player.is_downed:
		cancel()
	if not _active and _try_start(player, frame, delta):
		_active = true
		_time = 0.0
		player.weapons.set_trigger(false)
	if _active:
		_step(player, delta)
	return _active


func _try_start(player: Player, frame: InputFrame, delta: float) -> bool:
	if player.is_on_floor():
		_floor_y = player.global_position.y
	_window = JUMP_WINDOW if frame.has(InputFrame.JUMP) else maxf(_window - delta, 0.0)
	if not player.is_on_floor() and player.velocity.y < 0.0:
		_window = 0.0
	if _window <= 0.0 or player.mantle_rules == null:
		return false
	if player.is_downed or player.is_crouching or player.moves.is_sliding() or not player.input_enabled:
		return false
	return frame.move.y <= PUSH and _find_ledge(player)


func _find_ledge(player: Player) -> bool:
	var rules: MantleRules = player.mantle_rules
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	_setup(player)
	var feet: Vector3 = player.global_position
	_forward = -player.global_basis.z
	_forward.y = 0.0
	_forward = _forward.normalized()
	var low: float = _floor_y + rules.min_height - 0.05
	var wall: Dictionary = _cast(space, Vector3(feet.x, low, feet.z), _forward * (_radius + rules.reach))
	if wall.is_empty() or (wall.normal as Vector3).dot(_forward) > -0.5:
		return false
	var probe: Vector3 = (wall.position as Vector3) + _forward * PROBE_IN
	probe.y = _floor_y + rules.max_height + 0.1
	var top: Dictionary = _cast(space, probe, Vector3.DOWN * (rules.max_height - rules.min_height + 0.2))
	if top.is_empty() or (top.normal as Vector3).y < MIN_TOP_NORMAL:
		return false
	var top_y: float = (top.position as Vector3).y
	var height: float = top_y - _floor_y
	if height < rules.min_height or height > rules.max_height or feet.y > top_y - 0.05:
		return false
	_start = feet
	_top = Vector3(feet.x, top_y + MARGIN, feet.z)
	_end = (wall.position as Vector3) + _forward * (_radius + PROBE_IN)
	_end.y = top_y + MARGIN
	if _blocked(space, _top, ROOM_MASK) or _blocked(space, _end, ROOM_MASK):
		return false
	_duration = rules.duration(top_y - feet.y)
	return true


func _step(player: Player, delta: float) -> void:
	_time += delta
	var t: float = clampf(_time / maxf(_duration, 0.001), 0.0, 1.0)
	if t < RISE_SHARE:
		player.global_position = _start.lerp(_top, smoothstep(0.0, 1.0, t / RISE_SHARE))
	else:
		player.global_position = _top.lerp(_end, smoothstep(0.0, 1.0, (t - RISE_SHARE) / (1.0 - RISE_SHARE)))
	player.velocity = Vector3.ZERO
	if t >= 1.0:
		_active = false
		_window = 0.0
		player.velocity = _forward * player.walk_speed * EXIT_SPEED
		if _blocked(player.get_world_3d().direct_space_state, _end, Layers.WORLD):
			Log.warn(&"player", &"mantle_landed_blocked", {"at": _end})


func _setup(player: Player) -> void:
	if _room != null:
		return
	var collider: CollisionShape3D = player.get_node(^"CollisionShape3D") as CollisionShape3D
	_shape_offset = collider.position
	_radius = (collider.shape as CapsuleShape3D).radius
	_room = PhysicsShapeQueryParameters3D.new()
	_room.shape = collider.shape
	_room.exclude = [player.get_rid()]
	_ray.exclude = [player.get_rid()]
	_ray.collision_mask = WALL_MASK


func _cast(space: PhysicsDirectSpaceState3D, from: Vector3, along: Vector3) -> Dictionary:
	_ray.from = from
	_ray.to = from + along
	return space.intersect_ray(_ray)


func _blocked(space: PhysicsDirectSpaceState3D, feet: Vector3, mask: int) -> bool:
	_room.collision_mask = mask
	_room.transform = Transform3D(Basis.IDENTITY, feet + _shape_offset)
	return not space.intersect_shape(_room, 1).is_empty()

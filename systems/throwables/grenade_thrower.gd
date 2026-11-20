## The lethal slot: hold to pull the pin and cook, release to throw. The server
## owns the count (sent to clients by PlayerStateSync); the owner owns the cook and aim.
class_name GrenadeThrower
extends Node

const FRAG: ThrowableData = preload("res://content/throwables/frag.tres")
## The grenade leaves the hand this far in front of the eyes.
const HAND_DISTANCE: float = 0.5

var data: ThrowableData = FRAG
var count: int = 0
var cooking: bool = false
var fuse_left: float = 0.0
var _player: Player
var _was_held: bool = false


func _init() -> void:
	name = "GrenadeThrower"


func _ready() -> void:
	_player = get_parent() as Player
	count = data.carry
	Events.round_started.connect(_on_round_started)


## Called from the owner's Player.apply_frame each physics tick.
func tick(frame: InputFrame, delta: float) -> void:
	var held: bool = frame.has(InputFrame.LETHAL)
	if cooking:
		_cook(held, delta)
	elif held and not _was_held and can_start():
		cooking = true
		fuse_left = data.fuse
		_player.weapons.lower(data.recover_time)
	_was_held = held


func can_act() -> bool:
	var session: GameSession = _player.session
	return _player.input_enabled and _player.is_alive() and not _player.is_downed and not (session and session.is_over)


## Nobody throws in co-op until the request path exists (docs/plans/frag-grenades.md step 2).
func can_start() -> bool:
	var in_hub: bool = _player.session != null and _player.session.is_hub
	return count > 0 and not in_hub and can_act() and not Net.is_coop(multiplayer)


func _cook(held: bool, delta: float) -> void:
	fuse_left = maxf(fuse_left - delta, 0.0)
	if not can_act():
		throw(Vector3.ZERO)
		return
	_player.weapons.lower(data.recover_time)
	if fuse_left <= 0.0 or not held:
		throw(throw_velocity())


func throw_velocity() -> Vector3:
	var aim: Basis = PlayerCamera.aim_of(_player.camera)
	var forward: Vector3 = (-aim.z).rotated(aim.x.normalized(), deg_to_rad(data.throw_lift_degrees))
	return forward.normalized() * data.throw_speed + _player.velocity


## Throws with the fuse that is left; a zero velocity drops it where the player stands.
func throw(velocity: Vector3) -> Grenade:
	cooking = false
	count = maxi(count - 1, 0)
	_player.weapons.lower(data.recover_time)
	var parent: Node = _player.session if _player.session else _player.get_parent()
	var grenade: Grenade = Grenade.spawn(
		parent, data, _player, hand_position(velocity == Vector3.ZERO), velocity, fuse_left
	)
	_publish()
	return grenade


## In front of the eyes, pulled back if a wall is closer than that.
func hand_position(dropped: bool) -> Vector3:
	if dropped:
		return _player.global_position + Blast.LIFT
	var eye: Vector3 = _player.camera.global_position
	var forward: Vector3 = -PlayerCamera.aim_of(_player.camera).z
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		eye, eye + forward * HAND_DISTANCE, Layers.WORLD
	)
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return eye + forward * HAND_DISTANCE
	return (hit.position as Vector3) - forward * 0.1


## Server: back to a full carry (never takes extras away).
func refill() -> void:
	if multiplayer.is_server():
		count = maxi(count, data.carry)
		_publish()


func _on_round_started(_round_number: int, _count: int) -> void:
	refill()


func _publish() -> void:
	if _player.state_sync:
		_player.state_sync.queue_publish()

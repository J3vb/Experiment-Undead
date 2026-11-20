## The lethal slot: hold to pull the pin and cook, release to throw. The server
## owns the count (sent to clients by PlayerStateSync); the owner owns the cook and aim.
class_name GrenadeThrower
extends Node

const FRAG: ThrowableData = preload("res://content/throwables/frag.tres")
## The grenade leaves the hand this far in front of the eyes.
const HAND_DISTANCE: float = 0.5
## While cooking, a tick sounds this often.
const COOK_TICK: float = 0.5
const PIN_SOUND: AudioStream = preload("res://assets/audio/grenade_pin.wav")
const TICK_SOUND: AudioStream = preload("res://assets/audio/grenade_tick.wav")

var data: ThrowableData = FRAG
var count: int = 0
var cooking: bool = false
var fuse_left: float = 0.0
var _player: Player
var _was_held: bool = false
var _next_tick: float = 0.0
var _audio: AudioStreamPlayer


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
		_next_tick = data.fuse - COOK_TICK
		_player.weapons.lower(data.recover_time)
		play_sound(PIN_SOUND)
	_was_held = held


func can_act() -> bool:
	var session: GameSession = _player.session
	return _player.input_enabled and _player.is_alive() and not _player.is_downed and not (session and session.is_over)


## A client checks its synced count; the server checks again (GrenadeClaims).
func can_start() -> bool:
	var in_hub: bool = _player.session != null and _player.session.is_hub
	return count > 0 and not in_hub and can_act()


func _cook(held: bool, delta: float) -> void:
	fuse_left = maxf(fuse_left - delta, 0.0)
	if not can_act():
		throw(Vector3.ZERO)
		return
	_player.weapons.lower(data.recover_time)
	if fuse_left <= 0.0 or not held:
		throw(throw_velocity())
	elif fuse_left <= _next_tick:
		_next_tick -= COOK_TICK
		play_sound(TICK_SOUND)


## The owner's own grenade sounds (pin, cook ticks); nothing on a dedicated server.
func play_sound(stream: AudioStream) -> void:
	if Build.is_server():
		return
	if _audio == null:
		_audio = AudioStreamPlayer.new()
		_audio.bus = &"Weapons"
		add_child(_audio)
	_audio.stream = stream
	_audio.play()


func throw_velocity() -> Vector3:
	var aim: Basis = PlayerCamera.aim_of(_player.camera)
	var forward: Vector3 = (-aim.z).rotated(aim.x.normalized(), deg_to_rad(data.throw_lift_degrees))
	return forward.normalized() * data.throw_speed + _player.velocity


## Throws with the fuse that is left; a zero velocity drops it where the player stands.
## In a session the throw goes through GrenadeClaims, which owns the count; alone it is direct.
func throw(velocity: Vector3) -> void:
	cooking = false
	_player.weapons.lower(data.recover_time)
	var origin: Vector3 = hand_position(velocity == Vector3.ZERO)
	var claims: GrenadeClaims = _claims()
	if claims:
		claims.request_throw(_player, origin, velocity, fuse_left)
		return
	count = maxi(count - 1, 0)
	Grenade.spawn(_player.get_parent(), data, _player, origin, velocity, fuse_left)


func _claims() -> GrenadeClaims:
	return _player.session.get_node_or_null(^"GrenadeClaims") as GrenadeClaims if _player.session else null


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

## The local player's own footsteps and landing thud. Reads the parent Player
## after its physics tick; sound only, never changes gameplay.
class_name Footsteps
extends Node

@export var walk_interval: float = 0.5
@export var sprint_interval: float = 0.34
@export var crouch_interval: float = 0.72
## Below this horizontal speed (m/s) no steps play.
@export var min_step_speed: float = 1.2
## Landings slower than this (m/s down) make no thud; hard_land_speed is full volume.
@export var min_land_speed: float = 3.0
@export var hard_land_speed: float = 10.0
## Floors built from these materials sound like metal; everything else is concrete.
@export var metal_materials: Array[Material] = []

var _player: Player
var _step_left: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0

@onready var concrete: AudioStreamPlayer = $Concrete
@onready var metal: AudioStreamPlayer = $Metal
@onready var land: AudioStreamPlayer = $Land


func _ready() -> void:
	_player = get_parent() as Player


func _physics_process(delta: float) -> void:
	if _player == null or not _player.camera.current:
		return
	var on_floor: bool = _player.is_on_floor()
	if on_floor and not _was_on_floor:
		_play_landing(_fall_speed)
	_fall_speed = maxf(-_player.velocity.y, 0.0) if not on_floor else 0.0
	_was_on_floor = on_floor
	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	if advance(delta, speed, on_floor, _player.is_sprinting, _player.is_crouching):
		_play_step()


## Seconds between steps for the current move state.
func step_interval(sprinting: bool, crouching: bool) -> float:
	if crouching:
		return crouch_interval
	return sprint_interval if sprinting else walk_interval


## Counts down to the next step; true when a step should play this tick.
func advance(delta: float, speed: float, on_floor: bool, sprinting: bool, crouching: bool) -> bool:
	if not on_floor or speed < min_step_speed:
		_step_left = minf(_step_left, step_interval(sprinting, crouching) * 0.3)
		return false
	_step_left -= delta
	if _step_left > 0.0:
		return false
	_step_left += step_interval(sprinting, crouching)
	_step_left = maxf(_step_left, 0.0)
	return true


## Landing volume in dB for a fall speed, or -INF for no thud.
func landing_volume_db(fall_speed: float) -> float:
	if fall_speed < min_land_speed:
		return -INF
	var weight: float = clampf(inverse_lerp(min_land_speed, hard_land_speed, fall_speed), 0.0, 1.0)
	return lerpf(-14.0, 0.0, weight)


func is_metal(floor_body: Object) -> bool:
	var block: Block = floor_body as Block
	return block != null and metal_materials.has(block.material)


func _play_step() -> void:
	var player: AudioStreamPlayer = concrete
	for index: int in _player.get_slide_collision_count():
		var collision: KinematicCollision3D = _player.get_slide_collision(index)
		if collision.get_normal().y > 0.7 and is_metal(collision.get_collider()):
			player = metal
			break
	player.play()


func _play_landing(fall_speed: float) -> void:
	var volume: float = landing_volume_db(fall_speed)
	if volume == -INF:
		return
	land.volume_db = volume
	land.pitch_scale = lerpf(1.05, 0.85, db_to_linear(volume))
	land.play()

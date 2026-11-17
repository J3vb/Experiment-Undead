## Camera feel on top of the head: pitch, recoil spring, bob, crouch height
## and FOV for sprint/ADS. Attach to the Head node.
class_name PlayerCamera
extends Node3D

@export var sprint_fov_bonus: float = 6.0
@export var stand_height: float = 1.6
@export var crouch_height: float = 1.05
@export var bob_strength: float = 0.035

var base_fov: float = 78.0

var _recoil_target: Vector2 = Vector2.ZERO
var _recoil_current: Vector2 = Vector2.ZERO
var _recovery: float = 9.0
var _bob_time: float = 0.0
var _body: CharacterBody3D
var _tilt: Tween
var _tilt_degrees: float = 0.0

@onready var recoil_pivot: Node3D = $RecoilPivot
@onready var camera: Camera3D = $RecoilPivot/Camera3D


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	Settings.changed.connect(_on_setting_changed)
	_on_setting_changed(&"video", &"fov", Settings.get_value(&"video", &"fov"))


## Pitch only; yaw turns the body.
func add_pitch(radians: float) -> void:
	rotation.x = clampf(rotation.x + radians, deg_to_rad(-89.0), deg_to_rad(89.0))


## kick in degrees: x = yaw right, y = pitch up.
func add_recoil(kick: Vector2, recovery: float, permanent_ratio: float) -> void:
	_recovery = recovery
	var rad: Vector2 = Vector2(deg_to_rad(kick.y), deg_to_rad(-kick.x))
	_recoil_target += rad * (1.0 - permanent_ratio)
	add_pitch(rad.x * permanent_ratio)
	_body.rotate_y(rad.y * permanent_ratio)


## Down and death roll. Steps on the physics tick so the interpolated camera stays
## smooth; asking for the roll it already has or is heading to does nothing.
func tilt(degrees: float, time: float) -> Tween:
	if _tilt and _tilt.is_valid() and is_equal_approx(_tilt_degrees, degrees):
		return _tilt
	if _tilt:
		_tilt.kill()
	_tilt_degrees = degrees
	_tilt = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tilt.tween_property(self, "rotation:z", deg_to_rad(degrees), time)
	return _tilt


func add_flinch(strength_degrees: float, sideways: float) -> void:
	_recoil_target += Vector2(deg_to_rad(strength_degrees), deg_to_rad(sideways * strength_degrees * 0.6))


func update_feel(
	delta: float, crouching: bool, sprinting: bool, ads_progress: float, ads_fov: float, walk_speed: float
) -> void:
	var step: float = _recovery * delta * maxf(_recoil_target.length(), 0.02)
	_recoil_target = _recoil_target.move_toward(Vector2.ZERO, step)
	_recoil_current = _recoil_current.lerp(_recoil_target, clampf(25.0 * delta, 0.0, 1.0))
	recoil_pivot.rotation = Vector3(_recoil_current.x, _recoil_current.y, 0.0)

	var target_height: float = crouch_height if crouching else stand_height
	position.y = lerpf(position.y, target_height, clampf(10.0 * delta, 0.0, 1.0))

	var speed: float = Vector2(_body.velocity.x, _body.velocity.z).length()
	if _body.is_on_floor() and speed > 0.5:
		_bob_time += delta * speed * 1.6
	var amount: float = bob_strength * (1.0 - ads_progress) * clampf(speed / walk_speed, 0.0, 1.5)
	camera.position = Vector3(cos(_bob_time * 0.5) * amount * 0.5, sin(_bob_time) * amount, 0.0)

	var fov: float = base_fov + (sprint_fov_bonus if sprinting else 0.0)
	fov = lerpf(fov, ads_fov, ads_progress)
	camera.fov = lerpf(camera.fov, fov, clampf(12.0 * delta, 0.0, 1.0))


func _on_setting_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"video" and key == &"fov":
		base_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(float(value)) / 2.0) * 9.0 / 16.0))
		camera.fov = base_fov

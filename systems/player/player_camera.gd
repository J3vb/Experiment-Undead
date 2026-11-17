## Camera feel on top of the head: pitch, recoil spring, bob, crouch height,
## FOV for sprint/ADS, and the cosmetic layer (view kick, trauma shake, FOV punch).
## Cosmetic motion rotates only the Camera3D; aim comes from aim_of(). Attach to the Head node.
class_name PlayerCamera
extends Node3D

const FOV_PUNCH_MAX: float = 4.0
const FOV_PUNCH_RISE: float = 0.025

@export var sprint_fov_bonus: float = 6.0
@export var stand_height: float = 1.6
@export var crouch_height: float = 1.05
@export var bob_strength: float = 0.035
@export var rules: FeedbackRules

var base_fov: float = 78.0
## Comfort settings: head bob scale and whether sprinting widens the view.
var head_bob: float = 0.6
var sprint_fov: bool = true

var _recoil_target: Vector2 = Vector2.ZERO
var _recoil_current: Vector2 = Vector2.ZERO
var _recovery: float = 9.0
var _bob_time: float = 0.0
var _body: CharacterBody3D
var _tilt: Tween
var _tilt_degrees: float = 0.0
var _trauma: float = 0.0
var _view_kick: float = 0.0
var _view_kick_return: float = 0.075
var _punch_peak: float = 0.0
var _punch_time: float = 0.0
var _punch_length: float = 0.0
var _fov_current: float = 78.0
var _shake_time: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()

@onready var recoil_pivot: Node3D = $RecoilPivot
@onready var camera: Camera3D = $RecoilPivot/Camera3D


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if rules == null:
		rules = FeedbackRules.new()
	_noise.frequency = 1.0
	Settings.changed.connect(_on_setting_changed)
	_on_setting_changed(&"aim", &"fov", Settings.get_value(&"aim", &"fov"))
	head_bob = Settings.get_value(&"comfort", &"head_bob")
	sprint_fov = Settings.get_value(&"comfort", &"sprint_fov")
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.player_damaged.connect(_on_player_damaged)
	Events.round_started.connect(_on_round_started)


## Where bullets go from this camera: its parent's basis, without the camera's own
## cosmetic rotation (view kick and shake), so feel never moves the aim.
static func aim_of(view: Camera3D) -> Basis:
	var parent: Node3D = view.get_parent_node_3d()
	return parent.global_basis if parent else view.global_basis


func get_trauma() -> float:
	return _trauma


## Adds shake (0-1). own_gun picks the comfort slider; ADS halves it; firing alone
## never pushes trauma past fire_trauma_cap.
func add_trauma(amount: float, own_gun: bool) -> void:
	var scaled: float = amount * _comfort(own_gun) * lerpf(1.0, rules.ads_trauma_mult, _ads())
	var limit: float = maxf(_trauma, rules.fire_trauma_cap) if own_gun else 1.0
	_trauma = clampf(minf(_trauma + scaled, limit), 0.0, 1.0)


## Cosmetic camera kick for one shot of a gun with this feel.
func kick_view(feel: FeelData) -> void:
	if feel == null:
		return
	var comfort: float = _comfort(true)
	_view_kick = minf(_view_kick + feel.view_kick_pitch * comfort * lerpf(1.0, rules.ads_view_kick_mult, _ads()), 4.0)
	_view_kick_return = maxf(feel.view_kick_return_ms, 1.0) / 1000.0
	add_trauma(feel.fire_trauma, true)
	punch_fov(feel.fov_punch_deg * comfort, feel.fov_punch_ms / 1000.0)


## FOV offset in degrees (negative zooms in): rises in 25 ms, eases back over seconds.
func punch_fov(degrees: float, seconds: float) -> void:
	if is_zero_approx(degrees) or seconds <= 0.0:
		return
	_punch_peak = clampf(degrees, -FOV_PUNCH_MAX, FOV_PUNCH_MAX)
	_punch_time = 0.0
	_punch_length = seconds


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
	var amount: float = bob_strength * head_bob * (1.0 - ads_progress) * clampf(speed / walk_speed, 0.0, 1.5)
	camera.position = Vector3(cos(_bob_time * 0.5) * amount * 0.5, sin(_bob_time) * amount, 0.0)

	var fov: float = base_fov + (sprint_fov_bonus if sprinting and sprint_fov else 0.0)
	fov = lerpf(fov, ads_fov, ads_progress)
	_fov_current = lerpf(_fov_current, fov, clampf(12.0 * delta, 0.0, 1.0))
	camera.fov = _fov_current + _step_fov_punch(delta)
	_step_shake(delta)


func _step_shake(delta: float) -> void:
	_trauma = maxf(_trauma - rules.trauma_decay * delta, 0.0)
	_view_kick *= exp(-3.0 * delta / _view_kick_return)
	var shake: float = _trauma * _trauma
	_shake_time += delta * rules.shake_noise_hz
	var pitch: float = rules.max_shake_pitch_deg * shake * _noise.get_noise_2d(_shake_time, 0.0)
	var yaw: float = rules.max_shake_yaw_deg * shake * _noise.get_noise_2d(_shake_time, 100.0)
	var roll: float = rules.max_shake_roll_deg * shake * _noise.get_noise_2d(_shake_time, 200.0)
	camera.rotation = Vector3(deg_to_rad(_view_kick + pitch), deg_to_rad(yaw), deg_to_rad(roll))


func _step_fov_punch(delta: float) -> float:
	if _punch_length <= 0.0:
		return 0.0
	_punch_time += delta
	if _punch_time < FOV_PUNCH_RISE:
		return _punch_peak * _punch_time / FOV_PUNCH_RISE
	var t: float = (_punch_time - FOV_PUNCH_RISE) / _punch_length
	if t >= 1.0:
		_punch_length = 0.0
		return 0.0
	return _punch_peak * (1.0 - smoothstep(0.0, 1.0, t))


func _is_local() -> bool:
	return is_instance_valid(_body) and _body.is_multiplayer_authority()


func _ads() -> float:
	var player: Player = _body as Player
	return player.weapons.get_ads_progress() if player and player.weapons else 0.0


func _comfort(own_gun: bool) -> float:
	var value: Variant = Settings.get_value(&"comfort", &"shake_own_gun" if own_gun else &"shake_hits")
	return clampf(float(value), 0.0, 1.0) if value != null else 1.0


func _on_weapon_fired(player: Player, weapon: Weapon) -> void:
	if player == _body and _is_local() and weapon and weapon.data:
		kick_view(weapon.data.feel)


func _on_player_damaged(player: Player, _info: DamageInfo) -> void:
	if player == _body and _is_local():
		add_trauma(rules.hit_trauma, false)


func _on_round_started(_round_number: int, _count: int) -> void:
	if _is_local() and (_body as Player).is_alive():
		add_trauma(rules.round_start_trauma, false)


func _on_setting_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"aim" and key == &"fov":
		base_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(float(value)) / 2.0) * 9.0 / 16.0))
		camera.fov = base_fov
		_fov_current = base_fov
	elif section == &"comfort" and key == &"head_bob":
		head_bob = value
	elif section == &"comfort" and key == &"sprint_fov":
		sprint_fov = value

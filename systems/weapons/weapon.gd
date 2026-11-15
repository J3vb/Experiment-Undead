## Hitscan gun node driven by a WeaponInstance. Owns firing, spread, recoil,
## reload and the procedural viewmodel pose. Input arrives through the public
## vars, so a player, bot or test can drive it the same way.
class_name Weapon
extends Node3D

signal ammo_changed(in_mag: int, reserve: int)
signal fired
signal reload_started(duration: float)
signal hit_landed(is_kill: bool, is_headshot: bool)
## Presentation hook: where a bullet ended. Effects listen, logic never does.
signal traced(point: Vector3, normal: Vector3, hit_flesh: bool)

enum State { IDLE, RELOADING }

const BUFFER_TIME: float = 0.12

var instance: WeaponInstance
var data: WeaponData:
	get:
		return instance.data
var shooter: Player
var camera: Camera3D

var trigger_held: bool = false
var aiming: bool = false
var sprinting: bool = false
var move_factor: float = 0.0

var state: State = State.IDLE
var ads_progress: float = 0.0
var active: bool = false

var _shot_timer: float = 0.0
var _burst_left: int = 0
var _buffered: float = 0.0
var _trigger_was_held: bool = false
var _shots_in_string: int = 0
var _since_last_shot: float = 99.0
var _bloom: float = 0.0
var _sprint_block: float = 0.0
var _sprint_progress: float = 0.0
var _reload_timer: float = 0.0
var _reload_duration: float = 0.0
var _empty_reload: bool = false
var _kick: float = 0.0
var _flash_timer: float = 0.0
var _rng: RandomNumberGenerator

var _flash_light: Light3D
var _flash_mesh: Node3D
var _magazine: Node3D
var _bolt: Node3D
var _magazine_rest: Vector3
var _bolt_rest: Vector3

@onready var _viewmodel_root: Node3D = $Viewmodel
@onready var _fire_audio: AudioStreamPlayer = $FireAudio
@onready var _mech_audio: AudioStreamPlayer = $MechAudio


func setup(p_instance: WeaponInstance, p_shooter: Player, p_camera: Camera3D) -> void:
	instance = p_instance
	shooter = p_shooter
	camera = p_camera
	_rng = shooter.get_rng() if shooter else RandomNumberGenerator.new()


func _ready() -> void:
	if data.viewmodel_scene:
		var vm: Node = data.viewmodel_scene.instantiate()
		_viewmodel_root.add_child(vm)
		_find_moving_parts(vm)
	_set_flash(false)
	_fire_audio.stream = data.fire_sound
	position = data.hip_position
	fired.connect(_on_fired)
	traced.connect(_on_traced)


func _find_moving_parts(vm: Node) -> void:
	_flash_light = vm.find_child("FlashLight", true, false) as Light3D
	_flash_mesh = vm.find_child("FlashMesh", true, false) as Node3D
	_magazine = vm.find_child("Magazine", true, false) as Node3D
	_bolt = vm.find_child("Bolt", true, false) as Node3D
	if _magazine:
		_magazine_rest = _magazine.position
	if _bolt:
		_bolt_rest = _bolt.position
	for mesh: Node in vm.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mesh as MeshInstance3D).layers = ScopeLens.VIEWMODEL_LAYER


func set_active(value: bool) -> void:
	active = value
	visible = value
	if value:
		_emit_ammo()


func is_reloading() -> bool:
	return state == State.RELOADING


func get_current_spread() -> float:
	var base: float = lerpf(data.hip_spread, data.ads_spread, ads_progress)
	var movement: float = data.move_spread * move_factor * (1.0 - ads_progress * 0.8)
	return minf(base + movement + _bloom, data.max_spread)


func start_reload() -> bool:
	if state == State.RELOADING or not instance.needs_reload():
		return false
	state = State.RELOADING
	_burst_left = 0
	_empty_reload = instance.ammo_in_mag == 0
	_reload_duration = (data.empty_reload_time if _empty_reload else data.reload_time) * _stat(&"reload_time")
	_reload_timer = _reload_duration
	_play_mech(data.reload_sound)
	reload_started.emit(_reload_duration)
	return true


func _stat(stat: StringName) -> float:
	return shooter.get_stat(stat) if shooter else 1.0


func can_fire() -> bool:
	return active and state == State.IDLE and _sprint_block <= 0.0 and not sprinting


## Simulation step, run from the owner's physics tick.
func tick(delta: float) -> void:
	_tick_timers(delta)
	if state == State.RELOADING:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
	_handle_trigger()
	_trigger_was_held = trigger_held


## Presentation only: viewmodel pose and muzzle flash.
func _process(delta: float) -> void:
	if not active:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_set_flash(false)
	_update_pose(delta)


func _tick_timers(delta: float) -> void:
	_shot_timer -= delta
	_since_last_shot += delta
	_buffered = maxf(_buffered - delta, 0.0)
	_bloom = move_toward(_bloom, 0.0, data.spread_recovery * delta)
	_sprint_block = (
		data.sprint_to_fire_time * _stat(&"sprint_out_time") if sprinting else maxf(_sprint_block - delta, 0.0)
	)
	var ads_target: float = 1.0 if aiming and state != State.RELOADING else 0.0
	ads_progress = move_toward(ads_progress, ads_target, delta / maxf(data.ads_time * _stat(&"ads_time"), 0.01))
	_sprint_progress = move_toward(_sprint_progress, 1.0 if sprinting else 0.0, delta * 6.0)
	if _since_last_shot > (data.recoil.reset_time if data.recoil else 0.3):
		_shots_in_string = 0


func _handle_trigger() -> void:
	var pressed_now: bool = trigger_held and not _trigger_was_held
	if pressed_now:
		_buffered = BUFFER_TIME
	# Accumulator keeps the real fire rate independent of frame rate.
	while _shot_timer <= 0.0:
		var wants: bool = false
		match data.fire_mode:
			WeaponData.FireMode.AUTO:
				wants = trigger_held
			WeaponData.FireMode.SEMI:
				wants = _buffered > 0.0
			WeaponData.FireMode.BURST:
				if _burst_left == 0 and _buffered > 0.0:
					_burst_left = data.burst_count
				wants = _burst_left > 0
		if not wants or not can_fire():
			break
		_buffered = 0.0
		if instance.ammo_in_mag <= 0:
			_burst_left = 0
			_play_mech(data.dry_fire_sound)
			start_reload()
			break
		fire()
		_burst_left = maxi(_burst_left - 1, 0)
		var extra: float = 0.12 if data.fire_mode == WeaponData.FireMode.BURST and _burst_left == 0 else 0.0
		_shot_timer += data.get_fire_interval() * _stat(&"fire_interval") + extra
	# Time spent blocked (reloading, sprinting, waiting for a press) is not
	# banked as missed shots.
	_shot_timer = maxf(_shot_timer, 0.0)


## Fires one shot (all pellets) right now. Public for tests and AI.
func fire() -> void:
	instance.ammo_in_mag -= 1
	var spread: float = get_current_spread()
	var origin: Vector3 = camera.global_position
	var basis: Basis = camera.global_basis
	for i: int in data.pellets:
		_trace(origin, _spread_direction(basis, spread))

	_bloom = minf(_bloom + data.spread_per_shot, data.max_spread)
	_apply_recoil()
	_shots_in_string += 1
	_since_last_shot = 0.0
	fired.emit()
	_emit_ammo()
	if instance.ammo_in_mag == 0 and instance.ammo_reserve > 0:
		start_reload()


func _apply_recoil() -> void:
	if data.recoil == null or shooter == null:
		return
	var kick: Vector2 = data.recoil.get_kick(_shots_in_string, _rng)
	kick *= lerpf(1.0, data.recoil.ads_multiplier, ads_progress)
	shooter.camera_rig.add_recoil(kick, data.recoil.recovery_speed, data.recoil.permanent_ratio)


func _spread_direction(basis: Basis, spread_degrees: float) -> Vector3:
	var forward: Vector3 = -basis.z
	if spread_degrees <= 0.0:
		return forward
	var angle: float = deg_to_rad(spread_degrees) * sqrt(_rng.randf())
	var around: float = _rng.randf() * TAU
	var offset: Vector3 = (basis.x * cos(around) + basis.y * sin(around)) * tan(angle)
	return (forward + offset).normalized()


func _trace(origin: Vector3, direction: Vector3) -> void:
	var exclude: Array[RID] = []
	if shooter:
		exclude.append(shooter.get_rid())
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * data.max_range, Layers.WORLD | Layers.HIT_ZONE, exclude
	)
	query.collide_with_areas = true
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var point: Vector3 = result.position
	var normal: Vector3 = result.normal
	var hit_zone: HitZone = result.collider as HitZone
	traced.emit(point, normal, hit_zone != null)
	if hit_zone == null or not Net.is_authority():
		return
	var info: DamageInfo = DamageInfo.create(data.get_damage_at(origin.distance_to(point)), shooter)
	info.weapon_id = data.id
	info.position = point
	info.normal = normal
	info.impulse = direction * 2.0
	info.amount *= data.get_zone_multiplier(hit_zone.zone)
	if hit_zone.zone == DamageInfo.Zone.HEAD:
		info.amount *= _stat(&"head_damage")
	hit_zone.receive_hit(info)
	hit_landed.emit(hit_zone.health.is_dead, info.is_headshot())


func _on_fired() -> void:
	_kick = data.viewmodel_kick * lerpf(1.0, 0.5, ads_progress)
	_set_flash(true)
	_flash_timer = 0.045
	if _fire_audio.stream:
		_fire_audio.pitch_scale = randf_range(0.95, 1.05)  # cosmetic
		_fire_audio.play()


func _on_traced(point: Vector3, normal: Vector3, hit_flesh: bool) -> void:
	Impact.spawn(get_tree().current_scene, point, normal, Impact.Kind.FLESH if hit_flesh else Impact.Kind.SURFACE)


func _finish_reload() -> void:
	state = State.IDLE
	instance.refill_magazine()
	_emit_ammo()


func _update_pose(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, delta * 0.6)
	var pos: Vector3 = data.hip_position.lerp(data.ads_position, ads_progress)
	pos.z += _kick
	pos += Vector3(-0.08, -0.06, 0.04) * _sprint_progress
	var rot: Vector3 = Vector3(_kick * 2.0, 0.0, 0.0) + Vector3(-0.25, 0.7, 0.35) * _sprint_progress
	if state == State.RELOADING:
		var t: float = 1.0 - _reload_timer / maxf(_reload_duration, 0.001)
		var dip: float = sin(t * PI)
		pos += Vector3(0.0, -0.12, 0.02) * dip
		rot += Vector3(-0.5, 0.0, 0.6) * dip
	var smooth: float = clampf(delta * 25.0, 0.0, 1.0)
	position = position.lerp(pos, smooth)
	rotation = rotation.lerp(rot, smooth)
	_pose_moving_parts()


## Bolt rides back with the kick; on reload the magazine drops out and comes back.
func _pose_moving_parts() -> void:
	if _bolt:
		var back: float = _kick / maxf(data.viewmodel_kick, 0.001)
		if state == State.RELOADING and _empty_reload:
			back = 1.0
		_bolt.position = _bolt_rest + Vector3(0.0, 0.0, 0.035 * back)
	if _magazine:
		var out: float = 0.0
		if state == State.RELOADING:
			var t: float = 1.0 - _reload_timer / maxf(_reload_duration, 0.001)
			out = clampf(minf(t / 0.25, (0.85 - t) / 0.25), 0.0, 1.0)
		_magazine.position = _magazine_rest + Vector3(0.0, -0.22, 0.02) * out


func _set_flash(on: bool) -> void:
	if _flash_light:
		_flash_light.visible = on
	if _flash_mesh:
		_flash_mesh.visible = on
		if on:
			_flash_mesh.rotation.z = _rng.randf() * TAU


func _play_mech(stream: AudioStream) -> void:
	if stream:
		_mech_audio.stream = stream
		_mech_audio.play()


func _emit_ammo() -> void:
	if active:
		ammo_changed.emit(instance.ammo_in_mag, instance.ammo_reserve)

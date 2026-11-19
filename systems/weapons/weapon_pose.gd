## Viewmodel pose and visuals for a Weapon: hip/ADS/sprint/reload pose, kick, moving parts, flash, reload sounds.
class_name WeaponPose
extends Node

const CUES: Dictionary[StringName, AudioStream] = {
	&"mag_out": preload("res://assets/audio/reload_mag_out.wav"),
	&"mag_in": preload("res://assets/audio/reload_mag_in.wav"),
	&"bolt": preload("res://assets/audio/reload_bolt.wav"),
	&"shell_in": preload("res://assets/audio/reload_shell_in.wav"),
	&"pump": preload("res://assets/audio/reload_pump.wav"),
}

var weapon: Weapon
## Reload key poses, or null for guns that keep the dip (no Magazine, or no LoadShell on a round-by-round gun).
var motion: ReloadMotion
var mech_audio: AudioStreamPlayer
var _kick: float = 0.0
var _flash_timer: float = 0.0
var _flash_light: Light3D
var _flash_mesh: Node3D
var _magazine: Node3D
var _bolt: Node3D
var _magazine_rest: Vector3
var _bolt_rest: Vector3
var _mag_to_parent: Basis = Basis.IDENTITY
var _shell: bool = false
var _hand_target: Vector3 = Vector3.ZERO
var _hand_weight: float = 0.0
var _cue_t: float = 0.0
var _cue_empty: bool = false


static func attach_to(owner_weapon: Weapon) -> WeaponPose:
	var pose: WeaponPose = WeaponPose.new()
	pose.name = "Pose"
	pose.weapon = owner_weapon
	pose.mech_audio = owner_weapon.get_node_or_null(^"MechAudio") as AudioStreamPlayer
	owner_weapon.add_child(pose)
	return pose


func find_moving_parts(vm: Node) -> void:
	_flash_light = vm.find_child("FlashLight", true, false) as Light3D
	_flash_mesh = vm.find_child("FlashMesh", true, false) as Node3D
	_magazine = vm.find_child("Magazine", true, false) as Node3D
	if weapon.data.reload_per_round:
		_magazine = vm.find_child("LoadShell", true, false) as Node3D
		_shell = _magazine != null
	_bolt = vm.find_child("Bolt", true, false) as Node3D
	if _magazine:
		_magazine_rest = _magazine.position
		var parent: Node3D = _magazine.get_parent() as Node3D
		_mag_to_parent = (parent.global_basis.inverse() * weapon.global_basis).orthonormalized()
	if _shell:
		motion = ReloadMotion.from_shell(weapon, _magazine)
		_magazine.hide()
	elif not weapon.data.reload_per_round:
		motion = ReloadMotion.from_viewmodel(weapon, _magazine)
	if _bolt:
		_bolt_rest = _bolt.position
	for mesh: Node in vm.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mesh as MeshInstance3D).layers = ScopeLens.VIEWMODEL_LAYER


## Presentation step, run from the weapon's _process while it is active.
func update(delta: float) -> void:
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		set_flash(false)
	_update_pose(delta)


func on_fired() -> void:
	_kick = weapon.data.viewmodel_kick * lerpf(1.0, 0.5, weapon.ads_progress)
	set_flash(true)
	_flash_timer = 0.045


func set_flash(on: bool) -> void:
	on = on and not weapon.data.no_muzzle_flash
	if _flash_light:
		_flash_light.visible = on
	if _flash_mesh:
		_flash_mesh.visible = on
		if on:
			_flash_mesh.rotation.z = weapon._rng.randf() * TAU


func play_mech(stream: AudioStream) -> void:
	if stream:
		mech_audio.stream = stream
		mech_audio.play()


func _update_pose(delta: float) -> void:
	var data: WeaponData = weapon.data
	var sprint: float = weapon._sprint_progress
	_kick = move_toward(_kick, 0.0, delta * 0.6)
	var pos: Vector3 = data.hip_position.lerp(data.ads_position, weapon.ads_progress)
	pos.z += _kick
	pos += Vector3(-0.08, -0.06, 0.04) * sprint
	var rot: Vector3 = Vector3(_kick * 2.0, 0.0, 0.0) + Vector3(-0.25, 0.7, 0.35) * sprint
	var reloading: bool = weapon.state == Weapon.State.RELOADING
	if reloading and motion:
		var t: float = RoundReload.cycle_t(weapon) if _shell else _reload_t()
		motion.sample(weapon._empty_reload, t)
		_play_cue(t)
		pos += Vector3(-0.04, 0.075, -0.03) * motion.roll
		rot += Vector3(0.3, 0.25, -0.45) * motion.roll
	elif reloading:
		var dip: float = sin(_reload_t() * PI)
		pos += Vector3(0.0, -0.12, 0.02) * dip
		rot += Vector3(-0.5, 0.0, 0.6) * dip
	var smooth: float = clampf(delta * 25.0, 0.0, 1.0)
	if motion:
		_hand_weight = lerpf(_hand_weight, motion.hand_weight if reloading else 0.0, clampf(delta * 20.0, 0.0, 1.0))
		if reloading:
			_hand_target = motion.hand_target
	if not reloading:
		_cue_t = 0.0
	weapon.position = weapon.position.lerp(pos, smooth)
	weapon.rotation = weapon.rotation.lerp(rot, smooth)
	_pose_moving_parts()


## Plays each sound moment once as the reload passes it; a new shell cycle starts again from zero.
func _play_cue(t: float) -> void:
	if t < _cue_t or weapon._empty_reload != _cue_empty:
		_cue_t = 0.0
	var cue: StringName = motion.cue_between(weapon._empty_reload, _cue_t, t)
	if not cue.is_empty():
		play_mech(CUES[cue])
	_cue_t = t
	_cue_empty = weapon._empty_reload


## Support-hand offset from its grip, weapon-local, blended by the reload motion (zero when not reloading).
## It eases back to the grip when a reload is cancelled.
func reload_hand(grip_wrist: Vector3) -> Vector3:
	return (_hand_target - grip_wrist) * _hand_weight if motion else Vector3.ZERO


## How far the support hand may turn off its grip rotation (0 on the grip, 1 while it handles the magazine).
func reload_relax() -> float:
	return clampf(_hand_weight * 2.0, 0.0, 1.0) if motion else 0.0


func _pose_moving_parts() -> void:
	var reloading: bool = weapon.state == Weapon.State.RELOADING
	if motion:
		if _bolt:
			var kick: float = _kick / maxf(weapon.data.viewmodel_kick, 0.001)
			_bolt.position = _bolt_rest + Vector3(0.0, 0.0, 0.035 * maxf(kick, motion.bolt_back if reloading else 0.0))
		if _magazine:
			_magazine.position = _magazine_rest + (_mag_to_parent * motion.mag_offset if reloading else Vector3.ZERO)
			if _shell:
				_magazine.visible = reloading and motion.part_shown
		return
	if _bolt:
		var back: float = _kick / maxf(weapon.data.viewmodel_kick, 0.001)
		if reloading and weapon._empty_reload:
			back = 1.0
		_bolt.position = _bolt_rest + Vector3(0.0, 0.0, 0.035 * back)
	if _magazine:
		var out: float = 0.0
		if reloading:
			var t: float = _reload_t()
			out = clampf(minf(t / 0.25, (0.85 - t) / 0.25), 0.0, 1.0)
		_magazine.position = _magazine_rest + Vector3(0.0, -0.22, 0.02) * out


func _reload_t() -> float:
	return 1.0 - weapon._reload_timer / maxf(weapon._reload_duration, 0.001)

## A zombie's skinned body: poses its shared skeleton for walking, reaching,
## attacking, vaulting and death. Presentation only; the Zombie owns state.
class_name ZombieRig
extends Node3D

## A foot came down in the walk cycle (twice per cycle).
signal stepped

const PARTS: Dictionary[StringName, StringName] = {
	&"Hips": &"pelvis",
	&"Torso": &"spine_02",
	&"Head": &"head",
	&"ArmL": &"upperarm_L",
	&"ArmR": &"upperarm_R",
	&"LegL": &"thigh_L",
	&"LegR": &"thigh_R",
}
## Arm lift (radians) at the top of an attack wind-up, and the drop past rest at the end of the strike.
const ATTACK_LIFT: float = 1.3
const ATTACK_DROP: float = 0.7
## Arms start lifting toward a target closer than this.
const REACH_DISTANCE: float = 3.0
const CORPSE_TIME: float = 5.0
## How high the body hops at the middle of a window vault.
const VAULT_HEIGHT: float = 0.45
## Below this stride (a shuffle on the spot) no footsteps play.
const STEP_MIN_STRIDE: float = 0.2

## A skinned .glb (Tripo intake or zombie_model.py), facing +Z.
@export var model: PackedScene
## Other looks of the same zombie type; `look` picks one of `model` and these.
@export var extra_models: Array[PackedScene] = []
## Swell on hit in metres for the glowing parts (Bloater pods); 0 = none. Instance shader parameter `pulse`.
@export var pulse_size: float = 0.0

## Which look to show, the same on every peer (the Zombie sets it from its synced net_id).
var look: int = 0

var head: Node3D

var _skeleton: Skeleton3D
var _bones: Dictionary[StringName, int] = {}
var _rest: Dictionary[StringName, Quaternion] = {}
var _axes: Dictionary[StringName, Quaternion] = {}
var _offsets: Dictionary[StringName, Vector3] = {}
var _hips_rest: Vector3 = Vector3.ZERO
var _body_mesh: GeometryInstance3D
var _phase: float = 0.0
var _crawler: bool = false


func _ready() -> void:
	var looks: Array[PackedScene] = [model]
	looks.append_array(extra_models)
	var body: Node3D = looks[posmod(look, looks.size())].instantiate() as Node3D
	body.rotation.y = PI
	add_child(body)
	# Keep the existing horde's lighting cost: no per-frame lightmap probe capture.
	for mesh: Node in body.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_skeleton = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_crawler = body.find_child("Crawler", true, false) != null
	for part_name: StringName in PARTS:
		if _crawler and part_name in [&"LegL", &"LegR"]:
			continue
		_cache_bone(part_name, PARTS[part_name])
	for bone_name: StringName in [&"forearm_L", &"forearm_R", &"shin_L", &"shin_R"]:
		_cache_bone(bone_name, bone_name)
	_hips_rest = _skeleton.get_bone_pose_position(_bones[&"Hips"])
	_attach_head(body)
	_body_mesh = body.find_child("Body", true, false) as GeometryInstance3D


func _cache_bone(part_name: StringName, bone_name: StringName) -> void:
	var bone: int = _skeleton.find_bone(bone_name)
	_bones[part_name] = bone
	_rest[part_name] = _skeleton.get_bone_pose_rotation(bone)
	_axes[part_name] = _skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	_offsets[part_name] = Vector3.ZERO


func _attach_head(body: Node3D) -> void:
	head = body.find_child("HeadCenter", true, false) as Node3D
	var center: Transform3D = _skeleton.global_transform.affine_inverse() * head.global_transform
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "HeadAttachment"
	attachment.bone_name = &"head"
	_skeleton.add_child(attachment)
	attachment.transform = _skeleton.get_bone_global_rest(_bones[&"Head"])
	head.reparent(attachment, false)
	head.transform = attachment.transform.affine_inverse() * center


## Code-driven limb animation for the zombie's current state, until real clips arrive.
func follow(zombie: Zombie, delta: float) -> void:
	var t: float = zombie.state_time
	if zombie.state == Zombie.State.SPAWNING:
		position.y = lerpf(-1.8, 0.0, clampf(t / Zombie.SPAWN_TIME, 0.0, 1.0))
		return
	if zombie.state == Zombie.State.DEAD:
		return
	var vault: float = zombie.entry.vault_progress()
	if vault >= 0.0:
		pose_vault(vault)
		return
	position = position.lerp(Vector3.ZERO, clampf(delta * 10.0, 0.0, 1.0))
	if zombie.state == Zombie.State.ATTACKING:
		var windup: float = maxf(zombie.data.attack_windup, 0.01)
		if t < windup:
			pose_attack(t / windup)
		else:
			pose_attack(1.0 + (t - windup) / Zombie.STRIKE_TIME)
		return
	var reach: float = 0.0
	if zombie.state == Zombie.State.ENTERING:
		reach = 1.0
	elif zombie.target:
		var distance: float = zombie.global_position.distance_to(zombie.target.global_position)
		reach = clampf(1.0 - distance / REACH_DISTANCE, 0.0, 1.0)
	pose_walk(Vector2(zombie.velocity.x, zombie.velocity.z).length(), reach, delta)


## Limbs go slack, the body tips over onto a blood pool, lies for a while and
## sinks. Runs on every peer. Connect to the returned tween to free the zombie at the end.
## `popped`: killed by a headshot. `fresh`: seen dying, not a corpse a late joiner found,
## which gets the missing head but no pool or flying chunks.
func fall_over(popped: bool = false, fresh: bool = true) -> Tween:
	pose_dead()
	var scene: Node = get_tree().current_scene
	var parent: Node = scene if scene else get_tree().root
	if fresh:
		BloodPool.lay_death(parent, (get_parent() as Node3D).global_position)
	if popped and Impact.gore() == Impact.Gore.FULL and not Build.is_server():
		pop_head()
		if fresh:
			HeadPop.spawn(parent, head.global_position)
	var fall_dir: float = 1.0 if randf() < 0.5 else -1.0  # cosmetic
	var tween: Tween = create_tween()
	(
		tween
		. tween_property(self, "rotation", Vector3(deg_to_rad(-85.0), 0.0, deg_to_rad(10.0) * fall_dir), 0.45)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_interval(CORPSE_TIME)
	tween.tween_property(self, "position:y", -1.0, 1.5)
	return tween


## Collapses the head bone: the head and face skinned to it shrink into the neck, leaving a stump.
func pop_head() -> void:
	_skeleton.set_bone_pose_scale(_bones[&"Head"], Vector3.ONE * 0.01)


## The head bone's scale in skeleton space (1 normally, near 0 after pop_head).
func head_scale() -> float:
	return _skeleton.get_bone_global_pose(_bones[&"Head"]).basis.get_scale().x


func has_part(part_name: StringName) -> bool:
	return _bones.has(part_name)


## Limb angle away from the model's rest pose (x = pitch), for tests and effects.
func get_offset(part_name: StringName) -> Vector3:
	return _offsets.get(part_name, Vector3.ZERO)


## Walk cycle scaled by ground speed; `reach` (0..1) lifts the arms toward a close target.
func pose_walk(speed: float, reach: float, delta: float) -> void:
	if _crawler:
		_pose_crawl(speed, reach, delta)
		return
	var before: float = sin(_phase)
	_phase += delta * (1.5 + speed * 2.5)
	var stride: float = clampf(speed / 2.0, 0.0, 1.0)
	if stride > STEP_MIN_STRIDE and signf(sin(_phase)) != signf(before):
		stepped.emit()
	var swing: float = sin(_phase) * stride
	_pose_part(&"LegL", Vector3(swing * 0.55, 0.0, 0.0))
	_pose_part(&"LegR", Vector3(-swing * 0.55, 0.0, 0.0))
	var lift: float = -0.35 * reach
	_pose_part(&"ArmL", Vector3(lift - swing * 0.2 + sin(_phase * 0.7) * 0.1, 0.0, 0.0))
	_pose_part(&"ArmR", Vector3(lift + swing * 0.2 + cos(_phase * 0.8) * 0.1, 0.0, 0.0))
	_pose_part(&"Torso", Vector3(0.1 * stride + 0.05 * reach, 0.0, sin(_phase) * 0.07))
	_pose_part(&"Head", Vector3(0.0, 0.0, sin(_phase * 0.5) * 0.18))
	_pose_part(&"forearm_L", Vector3(-0.12 - 0.15 * reach, 0.0, 0.0))
	_pose_part(&"forearm_R", Vector3(-0.12 - 0.15 * reach, 0.0, 0.0))
	_pose_part(&"shin_L", Vector3(maxf(0.0, swing) * 0.3, 0.0, 0.0))
	_pose_part(&"shin_R", Vector3(maxf(0.0, -swing) * 0.3, 0.0, 0.0))
	var bob: Vector3 = Vector3.DOWN * absf(cos(_phase)) * 0.035 * stride
	_skeleton.set_bone_pose_position(_bones[&"Hips"], _hips_rest + bob)


## Attack swing. `t` 0..1 is the wind-up (arms rise, body leans back),
## 1..2 is the strike (arms slam down, body lunges).
func pose_attack(t: float) -> void:
	if _crawler:
		_pose_crawl_attack(t)
		return
	var arms: float
	var lean: float
	if t < 1.0:
		var up: float = ease(t, 0.5)
		arms = -ATTACK_LIFT * up
		lean = -0.15 * up
	else:
		var down: float = ease(clampf(t - 1.0, 0.0, 1.0), 0.3)
		arms = lerpf(-ATTACK_LIFT, ATTACK_DROP, down)
		lean = lerpf(-0.15, 0.3, down)
	_pose_part(&"ArmL", Vector3(arms, 0.0, 0.0))
	_pose_part(&"ArmR", Vector3(arms, 0.0, 0.0))
	_pose_part(&"Torso", Vector3(lean, 0.0, 0.0))
	_pose_part(&"LegL", Vector3(0.15, 0.0, 0.0))
	_pose_part(&"LegR", Vector3(-0.1, 0.0, 0.0))
	_pose_part(&"forearm_L", Vector3(-0.35, 0.0, 0.0))
	_pose_part(&"forearm_R", Vector3(-0.35, 0.0, 0.0))
	_pose_part(&"shin_L", Vector3(0.1, 0.0, 0.0))
	_pose_part(&"shin_R", Vector3(0.15, 0.0, 0.0))


func _pose_crawl(speed: float, reach: float, delta: float) -> void:
	_phase += delta * (1.5 + speed * 2.5)
	var swing: float = sin(_phase) * clampf(speed / 2.0, 0.0, 1.0)
	var lift: float = -0.12 - 0.16 * reach
	_pose_part(&"ArmL", Vector3(lift - swing * 0.12, 0.0, 0.0))
	_pose_part(&"ArmR", Vector3(lift + swing * 0.12, 0.0, 0.0))
	_pose_part(&"forearm_L", Vector3(-0.15 - maxf(swing, 0.0) * 0.18, 0.0, 0.0))
	_pose_part(&"forearm_R", Vector3(-0.15 - maxf(-swing, 0.0) * 0.18, 0.0, 0.0))
	_pose_part(&"Torso", Vector3(-0.025, 0.0, swing * 0.025))
	_pose_part(&"Head", Vector3(0.0, 0.0, sin(_phase * 0.5) * 0.06))
	_skeleton.set_bone_pose_position(_bones[&"Hips"], _hips_rest)


func _pose_crawl_attack(t: float) -> void:
	var raised: float = ease(clampf(t, 0.0, 1.0), 0.5)
	var lowered: float = ease(clampf(t - 1.0, 0.0, 1.0), 0.3)
	var lift: float = raised * (1.0 - lowered)
	_pose_part(&"ArmL", Vector3(-0.75 * lift, 0.0, 0.0))
	_pose_part(&"ArmR", Vector3(-0.75 * lift, 0.0, 0.0))
	_pose_part(&"forearm_L", Vector3(-0.14 - 0.18 * lift, 0.0, 0.0))
	_pose_part(&"forearm_R", Vector3(-0.14 - 0.18 * lift, 0.0, 0.0))
	_pose_part(&"Torso", Vector3(-0.10 * lift, 0.0, 0.0))
	_skeleton.set_bone_pose_position(_bones[&"Hips"], _hips_rest)


## Climb over a window sill. `t` 0..1: hands reach for the sill, the body
## hops up and pitches forward, legs tuck, then it drops into the room.
func pose_vault(t: float) -> void:
	var hop: float = sin(t * PI)
	position = Vector3(0.0, VAULT_HEIGHT * hop, 0.0)
	_pose_part(&"ArmL", Vector3(-1.4 + 0.9 * t, 0.0, -0.2))
	_pose_part(&"ArmR", Vector3(-1.4 + 0.9 * t, 0.0, 0.2))
	_pose_part(&"Torso", Vector3(0.6 * hop, 0.0, 0.0))
	_pose_part(&"LegL", Vector3(-0.9 * hop, 0.0, 0.0))
	_pose_part(&"LegR", Vector3(-0.6 * hop, 0.0, 0.0))
	_pose_part(&"Head", Vector3(-0.2 * hop, 0.0, 0.0))
	_pose_part(&"forearm_L", Vector3(-0.35 * hop, 0.0, 0.0))
	_pose_part(&"forearm_R", Vector3(-0.35 * hop, 0.0, 0.0))
	_pose_part(&"shin_L", Vector3(0.75 * hop, 0.0, 0.0))
	_pose_part(&"shin_R", Vector3(0.6 * hop, 0.0, 0.0))


## Limbs go slack as the body falls.
func pose_dead() -> void:
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var slack: Dictionary[StringName, Vector3] = {
		&"ArmL": Vector3(0.9, 0.0, -0.3),
		&"ArmR": Vector3(0.7, 0.0, 0.3),
		&"Head": Vector3(0.5, 0.0, 0.3),
		&"LegL": Vector3(0.2, 0.0, 0.0),
		&"LegR": Vector3(-0.15, 0.0, 0.0),
		&"Torso": Vector3.ZERO,
		&"forearm_L": Vector3(-0.2, 0.0, 0.0),
		&"forearm_R": Vector3(-0.15, 0.0, 0.0),
		&"shin_L": Vector3(0.25, 0.0, 0.0),
		&"shin_R": Vector3(0.2, 0.0, 0.0),
	}
	for part_name: StringName in slack:
		if _bones.has(part_name):
			tween.tween_method(_tween_pose.bind(part_name), get_offset(part_name), slack[part_name], 0.4)


## Bloater belly swells for a moment when hit (zombies with a `pulse_size`).
func pulse_belly() -> void:
	if _body_mesh == null or pulse_size <= 0.0:
		return
	_set_pulse(pulse_size)
	create_tween().tween_method(_set_pulse, pulse_size, 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC)


func pulse_amount() -> float:
	if _body_mesh == null:
		return 0.0
	var amount: Variant = _body_mesh.get_instance_shader_parameter(&"pulse")
	return amount if amount is float else 0.0


func _set_pulse(amount: float) -> void:
	_body_mesh.set_instance_shader_parameter(&"pulse", amount)


func _pose_part(part_name: StringName, offset: Vector3) -> void:
	if _bones.has(part_name):
		_offsets[part_name] = offset
		var turn: Quaternion = _axes[part_name].inverse() * Quaternion.from_euler(offset) * _axes[part_name]
		_skeleton.set_bone_pose_rotation(_bones[part_name], _rest[part_name] * turn)


func _tween_pose(offset: Vector3, part_name: StringName) -> void:
	_pose_part(part_name, offset)

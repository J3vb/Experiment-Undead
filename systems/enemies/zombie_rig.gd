## A zombie's visible body: loads its code-built model and poses the limbs in
## code (walk, reach, attack, death). Presentation only; the Zombie owns state.
class_name ZombieRig
extends Node3D

const PARTS: Array[StringName] = [&"Hips", &"Torso", &"Head", &"ArmL", &"ArmR", &"LegL", &"LegR"]
## Arm lift (radians) at the top of an attack wind-up, and the drop past rest at the end of the strike.
const ATTACK_LIFT: float = 1.3
const ATTACK_DROP: float = 0.7

## A .glb from tools/assets/build_models.py (faces +Z, one node per limb).
@export var model: PackedScene

var head: Node3D

var _parts: Dictionary[StringName, Node3D] = {}
var _rest: Dictionary[StringName, Vector3] = {}
var _hips_rest_y: float = 0.0
var _belly: Node3D
var _phase: float = 0.0


func _ready() -> void:
	var body: Node3D = model.instantiate() as Node3D
	body.rotation.y = PI
	add_child(body)
	for part_name: StringName in PARTS:
		var part: Node3D = body.find_child(part_name, true, false) as Node3D
		if part:
			_parts[part_name] = part
			_rest[part_name] = part.rotation
	head = _parts.get(&"Head")
	_belly = body.find_child("Belly", true, false) as Node3D
	if _parts.has(&"Hips"):
		_hips_rest_y = _parts[&"Hips"].position.y


func has_part(part_name: StringName) -> bool:
	return _parts.has(part_name)


## Limb angle away from the model's rest pose (x = pitch), for tests and effects.
func get_offset(part_name: StringName) -> Vector3:
	if not _parts.has(part_name):
		return Vector3.ZERO
	return _parts[part_name].rotation - _rest[part_name]


## Walk cycle scaled by ground speed; `reach` (0..1) lifts the arms toward a close target.
func pose_walk(speed: float, reach: float, delta: float) -> void:
	_phase += delta * (1.5 + speed * 2.5)
	var stride: float = clampf(speed / 2.0, 0.0, 1.0)
	var swing: float = sin(_phase) * stride
	_pose_part(&"LegL", Vector3(swing * 0.55, 0.0, 0.0))
	_pose_part(&"LegR", Vector3(-swing * 0.55, 0.0, 0.0))
	var lift: float = -0.35 * reach
	_pose_part(&"ArmL", Vector3(lift - swing * 0.2 + sin(_phase * 0.7) * 0.1, 0.0, 0.0))
	_pose_part(&"ArmR", Vector3(lift + swing * 0.2 + cos(_phase * 0.8) * 0.1, 0.0, 0.0))
	_pose_part(&"Torso", Vector3(0.1 * stride + 0.05 * reach, 0.0, sin(_phase) * 0.07))
	_pose_part(&"Head", Vector3(0.0, 0.0, sin(_phase * 0.5) * 0.18))
	if _parts.has(&"Hips"):
		_parts[&"Hips"].position.y = _hips_rest_y - absf(cos(_phase)) * 0.035 * stride


## Attack swing. `t` 0..1 is the wind-up (arms rise, body leans back),
## 1..2 is the strike (arms slam down, body lunges).
func pose_attack(t: float) -> void:
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


## Limbs go slack as the body falls (the Zombie tweens the fall itself).
func pose_dead() -> void:
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var slack: Dictionary[StringName, Vector3] = {
		&"ArmL": Vector3(0.9, 0.0, -0.3),
		&"ArmR": Vector3(0.7, 0.0, 0.3),
		&"Head": Vector3(0.5, 0.0, 0.3),
		&"LegL": Vector3(0.2, 0.0, 0.0),
		&"LegR": Vector3(-0.15, 0.0, 0.0),
		&"Torso": Vector3.ZERO,
	}
	for part_name: StringName in slack:
		if _parts.has(part_name):
			tween.tween_property(_parts[part_name], "rotation", _rest[part_name] + slack[part_name], 0.4)


## Bloater belly swells for a moment when hit.
func pulse_belly() -> void:
	if _belly == null:
		return
	_belly.scale = Vector3.ONE * 1.12
	create_tween().tween_property(_belly, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)


func _pose_part(part_name: StringName, offset: Vector3) -> void:
	if _parts.has(part_name):
		_parts[part_name].rotation = _rest[part_name] + offset

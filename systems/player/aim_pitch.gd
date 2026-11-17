## Bends the upper spine and head by the synced look pitch after the body clips play.
class_name AimPitch
extends SkeletonModifier3D

## Share of the pitch the chest takes; the head takes the rest.
const CHEST_SHARE: float = 0.4

var pitch_source: Node3D

var _chest: int = -1
var _head: int = -1
var _chest_axis: Quaternion
var _head_axis: Quaternion


func _ready() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	_chest = skeleton.find_bone("spine_03")
	_head = skeleton.find_bone("head")
	_chest_axis = skeleton.get_bone_global_rest(_chest).basis.get_rotation_quaternion()
	_head_axis = skeleton.get_bone_global_rest(_head).basis.get_rotation_quaternion()


func _process_modification_with_delta(_delta: float) -> void:
	if pitch_source == null:
		return
	var skeleton: Skeleton3D = get_skeleton()
	var pitch: float = -pitch_source.rotation.x
	_bend(skeleton, _chest, _chest_axis, pitch * CHEST_SHARE)
	_bend(skeleton, _head, _head_axis, pitch * (1.0 - CHEST_SHARE))


func _bend(skeleton: Skeleton3D, bone: int, axis: Quaternion, angle: float) -> void:
	var turn: Quaternion = axis.inverse() * Quaternion(Vector3.RIGHT, angle) * axis
	skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * turn)

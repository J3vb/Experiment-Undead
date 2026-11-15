## Solves the shared arm rig against weapon grips while shoulders stay in camera space.
class_name PlayerArmPose
extends RefCounted

var _flex_positive: bool = true
var _skeleton: Skeleton3D
var _upper: PackedInt32Array = []
var _lower: PackedInt32Array = []
var _hand: PackedInt32Array = []
var _upper_rest: Array[Transform3D] = []
var _lower_rest: Array[Transform3D] = []
var _hand_rest: Array[Transform3D] = []
var _upper_length: PackedFloat32Array = []
var _lower_length: PackedFloat32Array = []


func _init(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	for side: String in ["R", "L"]:
		var upper: int = skeleton.find_bone("upperarm_" + side)
		var lower: int = skeleton.find_bone("forearm_" + side)
		var hand: int = skeleton.find_bone("hand_" + side)
		_upper.append(upper)
		_lower.append(lower)
		_hand.append(hand)
		_upper_rest.append(skeleton.get_bone_global_rest(upper))
		_lower_rest.append(skeleton.get_bone_global_rest(lower))
		_hand_rest.append(skeleton.get_bone_global_rest(hand))
		_upper_length.append(skeleton.get_bone_rest(lower).origin.length())
		_lower_length.append(skeleton.get_bone_rest(hand).origin.length())


func pose(
	profile: PlayerArmProfiles.Profile, weapon_transform: Transform3D, pump_delta: Vector3 = Vector3.ZERO
) -> void:
	var travel: Vector3 = weapon_transform.origin - profile.hip_position
	var lift: Vector3 = Vector3(0, clampf(travel.y * 1.5, 0, .07), 0)
	lift.z = clampf(travel.z * .5, 0, lift.y * 1.6)
	_arm(0, profile.right, weapon_transform, Vector3.ZERO, lift)
	lift.y += clampf(travel.y * .35, -.04, 0)
	_arm(1, profile.left, weapon_transform, pump_delta, lift)


func _arm(
	index: int, grip: PlayerArmProfiles.Hand, weapon_transform: Transform3D, part_delta: Vector3, lift: Vector3
) -> void:
	var rotation: Basis = weapon_transform.basis * grip.rotation
	var target: Transform3D = Transform3D(
		rotation * _hand_rest[index].basis, weapon_transform * (grip.wrist + part_delta)
	)
	var palm: Vector3 = target.basis.y.normalized()
	var dorsal: Vector3 = rotation * Vector3.FORWARD
	var shoulder: Vector3 = grip.shoulder + lift
	var elbow: Vector3 = _elbow(index, shoulder, target.origin, palm, dorsal)
	var forearm: Vector3 = target.origin - elbow
	_set_bone(_upper[index], _upper_rest[index], shoulder, elbow - shoulder, dorsal)
	_set_bone(_lower[index], _lower_rest[index], elbow, forearm, _forearm_dorsal(forearm, palm, dorsal))
	_skeleton.set_bone_global_pose(_hand[index], target)


func _elbow(index: int, shoulder: Vector3, wrist: Vector3, palm: Vector3, dorsal: Vector3) -> Vector3:
	var offset: Vector3 = wrist - shoulder
	var direction: Vector3 = offset.normalized()
	var upper: float = _upper_length[index]
	var lower: float = _lower_length[index]
	var distance: float = clampf(offset.length(), absf(upper - lower) + .0001, upper + lower - .0001)
	var along: float = (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, upper * upper - along * along))
	var bend: Vector3 = _bend(palm, direction, index) * height
	var center: Vector3 = shoulder + direction * along
	var frame: Basis = Basis(bend, direction.cross(bend), center)
	# Keep one twist branch throughout the circle search so the elbow cannot pop.
	var preferred: Vector3 = (wrist - center - bend).normalized()
	_flex_positive = palm.dot(dorsal - preferred * dorsal.dot(preferred)) >= 0
	if _elbow_score(center + bend, shoulder, wrist, palm, dorsal, index) == 0.0:
		return center + bend
	# Search the elbow circle continuously so grips and segment lengths stay exact.
	var low: float = -PI * .5
	var high: float = PI * .5
	for _step: int in 18:
		var first: float = lerpf(low, high, .381966)
		var second: float = lerpf(low, high, .618034)
		var score_a: float = (
			_elbow_score(_circle(frame, first), shoulder, wrist, palm, dorsal, index) + first * first * .0001
		)
		var score_b: float = (
			_elbow_score(_circle(frame, second), shoulder, wrist, palm, dorsal, index) + second * second * .0001
		)
		if score_a < score_b:
			high = second
		else:
			low = first
	return _circle(frame, (low + high) * .5)


func _bend(palm: Vector3, direction: Vector3, index: int) -> Vector3:
	var bend: Vector3 = -palm + direction * palm.dot(direction)
	if bend.length_squared() < .000001:
		var outward: Vector3 = Vector3(1.0 if index == 0 else -1.0, -1, 0)
		bend = outward - direction * outward.dot(direction)
	if bend.length_squared() < .000001:
		bend = direction.cross(Vector3.FORWARD)
	return bend.normalized()


func _circle(frame: Basis, angle: float) -> Vector3:
	return frame.z + frame.x * cos(angle) + frame.y * sin(angle)


func _elbow_score(
	elbow: Vector3, shoulder: Vector3, wrist: Vector3, palm: Vector3, dorsal: Vector3, index: int
) -> float:
	var forward: Vector3 = (wrist - elbow).normalized()
	var outward: Vector3 = _forearm_dorsal(forward, palm, dorsal)
	var along: float = palm.dot(forward)
	var flex: float = absf(atan2(palm.dot(outward), along))
	var deviation: float = absf(atan2(palm.dot(outward.cross(forward)), along))
	var wrist_bend: float = forward.angle_to(palm)
	var side: float = 1.0 if index == 0 else -1.0
	var cost: float = pow(maxf(0, wrist_bend - deg_to_rad(34.5)), 2)
	cost += pow(maxf(0, flex - deg_to_rad(29.5)), 2)
	cost += pow(maxf(0, deviation - deg_to_rad(19.5)), 2)
	cost += pow(maxf(0, .005 - elbow.x * side) * 10, 2)
	cost += pow(maxf(0, elbow.y - shoulder.y - .01) * 10, 2)
	cost += pow(maxf(0, elbow.y - wrist.y + .005) * 10, 2)
	return cost


func _forearm_dorsal(direction: Vector3, palm: Vector3, dorsal: Vector3) -> Vector3:
	var forward: Vector3 = direction.normalized()
	var outward: Vector3 = (dorsal - forward * dorsal.dot(forward)).normalized()
	var lateral: Vector3 = outward.cross(forward)
	var across: float = palm.dot(lateral)
	var limit: float = maxf(0, palm.dot(forward)) * tan(deg_to_rad(19.5))
	if absf(across) <= limit:
		return outward
	var flex: float = palm.dot(outward)
	var angle: float = atan2(across, flex)
	var boundary: float = asin(clampf(limit / Vector2(flex, across).length(), 0, 1))
	var desired: float = signf(angle) * (boundary if _flex_positive else PI - boundary)
	var transported: Vector3 = Basis(Quaternion(forward, palm)) * outward
	var roll: float = transported.signed_angle_to(dorsal, palm)
	var turn: float = clampf(wrapf(desired - angle, -PI, PI), roll - deg_to_rad(19.5), roll + deg_to_rad(19.5))
	return outward.rotated(forward, turn)


func _set_bone(index: int, rest: Transform3D, at: Vector3, direction: Vector3, dorsal: Vector3) -> void:
	var rotation: Basis = _basis(direction, dorsal) * _basis(rest.basis.y, Vector3.FORWARD).inverse()
	_skeleton.set_bone_global_pose(index, Transform3D(rotation * rest.basis, at))


func _basis(direction: Vector3, dorsal: Vector3) -> Basis:
	var axis: Vector3 = direction.normalized()
	var outward: Vector3 = (dorsal - axis * dorsal.dot(axis)).normalized()
	return Basis(outward.cross(axis), outward, axis)

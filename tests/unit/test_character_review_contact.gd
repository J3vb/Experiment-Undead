## Evaluate imported skin vertices against the unchanged rifle's grip and handguard envelopes.
extends GutTest

const REVIEW: Script = preload("res://tools/character_review.gd")
const ARMS: PackedScene = preload("res://assets/models/characters/player_arms.glb")
const GRIP: Array[Vector2] = [
	Vector2(-0.09, -0.048),
	Vector2(-0.122, -0.048),
	Vector2(-0.168, -0.152),
	Vector2(-0.164, -0.166),
	Vector2(-0.128, -0.166),
	Vector2(-0.118, -0.152),
	Vector2(-0.113, -0.13),
	Vector2(-0.104, -0.114),
	Vector2(-0.1, -0.094),
	Vector2(-0.092, -0.078),
]
const GUARD: Array[Vector2] = [
	Vector2(.016, -.05),
	Vector2(.016, -.086),
	Vector2(-.082, -.086),
	Vector2(-.096, -.05),
	Vector2(-.088, -.05),
	Vector2(-.077, -.079),
	Vector2(.009, -.079),
	Vector2(.009, -.05),
]
const TRIGGER: Array[Vector2] = [
	Vector2(-.035, -.05),
	Vector2(-.029, -.05),
	Vector2(-.031, -.064),
	Vector2(-.039, -.076),
	Vector2(-.044, -.073),
	Vector2(-.037, -.063),
]
const LOWER: Array[Vector2] = [
	Vector2(-.168, -.004),
	Vector2(.122, -.004),
	Vector2(.122, -.026),
	Vector2(.114, -.09),
	Vector2(.02, -.09),
	Vector2(.016, -.05),
	Vector2(-.13, -.05),
	Vector2(-.168, -.028),
]
const UPPER: Array[Vector2] = [
	Vector2(-.17, -.004),
	Vector2(.17, -.004),
	Vector2(.17, .046),
	Vector2(-.152, .046),
	Vector2(-.17, .034),
]
# This filled envelope includes the rail teeth gaps, so a clear result is conservative.
const RAIL: Array[Vector2] = [
	Vector2(-.168, .046),
	Vector2(.475, .046),
	Vector2(.475, .059),
	Vector2(-.168, .059),
]


func _hand_points(side: String) -> PackedVector3Array:
	var arms: Node3D = ARMS.instantiate() as Node3D
	add_child_autofree(arms)
	var skeleton: Skeleton3D = arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh: MeshInstance3D = arms.find_child("PlayerArms", true, false) as MeshInstance3D
	REVIEW._rifle_arm(skeleton, side)
	var transforms: Array[Transform3D] = []
	var hand_bind: int = -1
	for index: int in mesh.skin.get_bind_count():
		var name: StringName = mesh.skin.get_bind_name(index)
		var bone: int = skeleton.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(index)
		transforms.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(index))
		if skeleton.get_bone_name(bone) == "hand_" + side:
			hand_bind = index
	assert_ne(hand_bind, -1, "hand skin binding must exist")
	var points: PackedVector3Array = []
	for surface: int in mesh.mesh.get_surface_count():
		points.append_array(_surface_points(mesh.mesh.surface_get_arrays(surface), transforms, hand_bind))
	return points


func _surface_points(arrays: Array, transforms: Array[Transform3D], hand_bind: int) -> PackedVector3Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var points: PackedVector3Array = []
	var influences: int = bones.size() / vertices.size()
	for index: int in vertices.size():
		var point: Vector3 = Vector3.ZERO
		var hand_weight: float = 0.0
		for influence: int in influences:
			var slot: int = index * influences + influence
			point += transforms[bones[slot]] * vertices[index] * weights[slot]
			if bones[slot] == hand_bind:
				hand_weight += weights[slot]
		if hand_weight > 0.95:
			var relative: Vector3 = point - REVIEW.RIFLE_POSITION
			points.append(Vector3(relative.x, -relative.z, relative.y))
	return points


func test_left_hand_contacts_handguard_without_entering_its_octagonal_shell() -> void:
	var points: PackedVector3Array = _hand_points("L")
	var minimum: float = INF
	var samples: int = 0
	for point: Vector3 in points:
		if point.y < 0.175 or point.y > 0.465:
			continue
		var x: float = absf(point.x)
		var z: float = absf(point.z - 0.016)
		var distance: float = maxf(maxf(x, z), (x + z) / sqrt(2.0)) - 0.033 * cos(PI / 8.0)
		minimum = minf(minimum, distance)
		samples += 1
	gut.p("Handguard minimum signed clearance: %.3f mm (%d vertices)" % [minimum * 1000.0, samples])
	assert_gt(samples, 200, "the support hand must occupy the actual handguard interval")
	assert_gte(minimum, -0.0012, "handguard penetration in metres")
	assert_lt(minimum, 0.006, "the support hand must touch, rather than float below, the handguard")


func _outline_distance(point: Vector2, outline: Array[Vector2] = GRIP) -> float:
	var distance: float = INF
	for index: int in outline.size():
		var start: Vector2 = outline[index]
		var edge: Vector2 = outline[(index + 1) % outline.size()] - start
		var along: float = clampf((point - start).dot(edge) / edge.length_squared(), 0.0, 1.0)
		distance = minf(distance, point.distance_to(start + edge * along))
	return -distance if Geometry2D.is_point_in_polygon(point, PackedVector2Array(outline)) else distance


func test_right_hand_contacts_pistol_grip_without_entering_its_slab() -> void:
	var minimum: float = INF
	var samples: int = 0
	for point: Vector3 in _hand_points("R"):
		if point.z < -0.18 or point.z > -0.04:
			continue
		var distance: float = maxf(absf(point.x) - 0.016, _outline_distance(Vector2(point.y, point.z)))
		minimum = minf(minimum, distance)
		samples += 1
	gut.p("Pistol grip minimum signed clearance: %.3f mm (%d vertices)" % [minimum * 1000.0, samples])
	assert_gt(samples, 200, "the firing hand must occupy the actual pistol grip interval")
	assert_gte(minimum, -0.002, "pistol grip penetration in metres, including the bevel envelope")
	assert_lt(minimum, 0.006, "the firing hand must touch, rather than float away from, the pistol grip")


func test_oblique_grasps_keep_their_handed_frame_and_positive_rotation() -> void:
	var arms: Node3D = ARMS.instantiate() as Node3D
	add_child_autofree(arms)
	var skeleton: Skeleton3D = arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for side: String in ["R", "L"]:
		REVIEW._rifle_arm(skeleton, side)
		var hand: int = skeleton.find_bone("hand_" + side)
		var rotation: Basis = (
			skeleton.get_bone_global_pose(hand).basis * skeleton.get_bone_global_rest(hand).basis.inverse()
		)
		var across: Vector3 = Vector3(1 if side == "R" else -1, -1, 0).normalized()
		var expected: Vector3 = Vector3(0, -sqrt(0.75), -0.5) if side == "R" else Vector3(0.6, 0, 0.8)
		assert_almost_eq(rotation * across, expected, Vector3.ONE * 0.0001)
		assert_almost_eq(rotation.determinant(), 1.0, 0.0001, "fitting must never mirror bones")


func _slab_clearance(points: PackedVector3Array, outline: Array[Vector2], half_width: float) -> float:
	var minimum: float = INF
	for point: Vector3 in points:
		var distance: float = maxf(absf(point.x) - half_width, _outline_distance(Vector2(point.y, point.z), outline))
		minimum = minf(minimum, distance)
	return minimum


func test_right_hand_clears_the_trigger_guard_trigger_and_lower_receiver() -> void:
	var points: PackedVector3Array = _hand_points("R")
	var guard: float = _slab_clearance(points, GUARD, .006)
	var trigger: float = _slab_clearance(points, TRIGGER, .003)
	var lower: float = _slab_clearance(points, LOWER, .023)
	gut.p("Right guard %.3f / trigger %.3f / lower %.3f mm" % [guard * 1000, trigger * 1000, lower * 1000])
	assert_gte(guard, 0.0, "glove must stay outside the trigger guard, including the index finger")
	assert_gte(trigger, 0.0, "inspection grip must not pass through the trigger")
	assert_gte(lower, 0.0, "glove must stay outside the lower receiver")


func test_both_hands_clear_the_upper_receiver_and_full_rail_envelope() -> void:
	for side: String in ["R", "L"]:
		var points: PackedVector3Array = _hand_points(side)
		var upper: float = _slab_clearance(points, UPPER, .025)
		var rail: float = _slab_clearance(points, RAIL, .012)
		gut.p("%s upper receiver %.3f / rail %.3f mm" % [side, upper * 1000, rail * 1000])
		assert_gte(upper, 0.0, side + " glove must stay outside the upper receiver")
		assert_gte(rail, 0.0, side + " glove must stay outside the rail, including its teeth")
	var left_lower: float = _slab_clearance(_hand_points("L"), LOWER, .023)
	gut.p("Left lower receiver %.3f mm" % [left_lower * 1000])
	assert_gte(left_lower, 0.0, "the support hand must clear the lower receiver")

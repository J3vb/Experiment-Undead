## The prone rig keeps the actual skinned palm and finger vertices above the floor.
extends GutTest

const STEPS: int = 96


func _crawler() -> ZombieRig:
	var rig: ZombieRig = ZombieRig.new()
	rig.model = load("res://assets/models/zombies/crawler.glb") as PackedScene
	add_child_autofree(rig)
	return rig


func _hand_vertices(rig: ZombieRig, skeleton: Skeleton3D) -> Array[Dictionary]:
	var anatomy: MeshInstance3D = rig.find_child("AnatomyDetails", true, false) as MeshInstance3D
	var result: Array[Dictionary] = []
	for surface: int in anatomy.mesh.get_surface_count():
		var arrays: Array = anatomy.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influences: int = bones.size() / vertices.size()
		for index: int in vertices.size():
			var sample: Dictionary = {"bones": [], "points": [], "weights": []}
			var is_hand: bool = false
			for influence: int in influences:
				var weight: float = weights[index * influences + influence]
				if weight <= 0.0:
					continue
				var bind: int = bones[index * influences + influence]
				var bone: int = anatomy.skin.get_bind_bone(bind)
				if bone < 0:
					bone = skeleton.find_bone(anatomy.skin.get_bind_name(bind))
				var bone_name: String = skeleton.get_bone_name(bone)
				is_hand = is_hand or bone_name.begins_with("hand_")
				sample["bones"].append(bone)
				sample["points"].append(anatomy.skin.get_bind_pose(bind) * vertices[index])
				sample["weights"].append(weight)
			if is_hand:
				result.append(sample)
	return result


func _minimum_height(skeleton: Skeleton3D, samples: Array[Dictionary]) -> float:
	skeleton.force_update_all_bone_transforms()
	var minimum: float = INF
	for sample: Dictionary in samples:
		var point: Vector3 = Vector3.ZERO
		for index: int in sample["bones"].size():
			var bone: int = sample["bones"][index]
			var local: Vector3 = sample["points"][index]
			point += (skeleton.get_bone_global_pose(bone) * local) * float(sample["weights"][index])
		minimum = minf(minimum, (skeleton.global_transform * point).y)
	return minimum


func test_full_crawl_cycles_keep_fingers_clear_at_all_speeds_and_reaches() -> void:
	var rig: ZombieRig = _crawler()
	var skeleton: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var samples: Array[Dictionary] = _hand_vertices(rig, skeleton)
	assert_gt(samples.size(), 100, "check skinned palms, fingers and thumbs, not only bone origins")
	for speed: float in [0.0, 1.0, 2.0, 5.0]:
		for reach: float in [0.0, 0.5, 1.0]:
			var minimum: float = INF
			var delta: float = TAU / ((1.5 + speed * 2.5) * STEPS)
			for _step: int in STEPS:
				rig.pose_walk(speed, reach, delta)
				minimum = minf(minimum, _minimum_height(skeleton, samples))
			assert_gt(minimum, 0.01, "full cycle clearance at speed %s / reach %s" % [speed, reach])
	assert_eq(rig.position, Vector3.ZERO, "pose correction keeps the model's floor pivot")


func test_full_crawler_attack_after_walking_keeps_fingers_above_the_floor() -> void:
	var rig: ZombieRig = _crawler()
	var skeleton: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var samples: Array[Dictionary] = _hand_vertices(rig, skeleton)
	rig.pose_walk(2.0, 0.0, PI / 13.0)
	var minimum: float = INF
	for step: int in STEPS * 2 + 1:
		rig.pose_attack(float(step) / STEPS)
		minimum = minf(minimum, _minimum_height(skeleton, samples))
	assert_gt(minimum, 0.01, "entire windup and strike keep the digits clear")
	assert_eq(rig.position, Vector3.ZERO, "attack does not move the root to hide a bad hand pose")

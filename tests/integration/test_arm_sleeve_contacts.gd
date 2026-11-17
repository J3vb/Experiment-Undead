## The right upper sleeve stays clear of the Coachman and Bastion stocks in every exported pose.
## Mirrors tools/character_contact_export.gd: skins the imported arms and checks sleeve edges against the gun.
extends GutTest

const GUNS: Array[StringName] = [&"coachman_2b", &"bastion_lmg"]
const SLEEVE_BONE: String = "upperarm_R"


func _holder(id: StringName) -> WeaponHolder:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	var holder: WeaponHolder = WeaponHolder.new()
	camera.add_child(holder)
	holder.setup(null, camera)
	holder.set_process(false)
	var weapon: Weapon = holder.give(Content.weapon(id))
	weapon.set_process(false)
	holder.arm_view.set_process(false)
	return holder


func _weapon_mesh(weapon: Weapon) -> TriangleMesh:
	var faces: PackedVector3Array = []
	for node: Node in weapon.get_node("Viewmodel").find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		if not instance.is_visible_in_tree() or instance.mesh == null or instance.name == &"FlashMesh":
			continue
		for face: Vector3 in instance.mesh.get_faces():
			faces.append(instance.global_transform * face)
	var result: TriangleMesh = TriangleMesh.new()
	assert_true(result.create_from_faces(faces), "weapon faces build a triangle mesh")
	return result


func _sleeve_edges(view: PlayerArmView) -> PackedVector3Array:
	var skin: Skin = view.mesh.skin
	var binds: Array[Transform3D] = []
	var sleeve: int = -1
	for index: int in skin.get_bind_count():
		var bone: int = view.skeleton.find_bone(skin.get_bind_name(index))
		binds.append(
			view.skeleton.global_transform * view.skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(index)
		)
		if skin.get_bind_name(index) == SLEEVE_BONE:
			sleeve = index
	assert_gte(sleeve, 0, "the arm skin binds the right upper arm")
	var edges: PackedVector3Array = []
	for surface: int in view.mesh.mesh.get_surface_count():
		edges.append_array(_surface_edges(view.mesh.mesh.surface_get_arrays(surface), binds, sleeve))
	return edges


func _surface_edges(arrays: Array, binds: Array[Transform3D], sleeve: int) -> PackedVector3Array:
	var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / source.size()
	var points: PackedVector3Array = []
	var on_sleeve: PackedByteArray = []
	for index: int in source.size():
		var point: Vector3 = Vector3.ZERO
		var sleeve_weight: float = 0.0
		for slot: int in range(index * influences, (index + 1) * influences):
			point += binds[bones[slot]] * source[index] * weights[slot]
			sleeve_weight += weights[slot] if bones[slot] == sleeve else 0.0
		points.append(point)
		on_sleeve.append(1 if sleeve_weight > .5 else 0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var edges: PackedVector3Array = []
	for start: int in range(0, indices.size(), 3):
		for side: int in 3:
			var first: int = indices[start + side]
			var second: int = indices[start + (side + 1) % 3]
			if on_sleeve[first] and on_sleeve[second]:
				edges.append(points[first])
				edges.append(points[second])
	return edges


func _crossings(holder: WeaponHolder) -> int:
	holder.arm_view.update_pose()
	var gun: TriangleMesh = _weapon_mesh(holder.current)
	var edges: PackedVector3Array = _sleeve_edges(holder.arm_view)
	assert_gt(edges.size(), 100, "the right upper sleeve has edges to check")
	var count: int = 0
	for index: int in range(0, edges.size(), 2):
		if not gun.intersect_segment(edges[index], edges[index + 1]).is_empty():
			count += 1
	return count


func _hip(weapon: Weapon) -> void:
	weapon.aiming = false
	weapon.sprinting = false
	weapon.tick(1.0)
	weapon._process(1.0)


func test_right_upper_sleeve_clears_the_stock_through_hip_ads_sprint_and_shot() -> void:
	for id: StringName in GUNS:
		var holder: WeaponHolder = _holder(id)
		var weapon: Weapon = holder.current
		weapon._process(.05)
		assert_eq(_crossings(holder), 0, "%s hip" % id)
		weapon.aiming = true
		weapon.tick(weapon.data.ads_time * .5)
		weapon._process(.05)
		assert_eq(_crossings(holder), 0, "%s mid ADS" % id)
		_hip(weapon)
		weapon.sprinting = true
		weapon.tick(1.0)
		weapon._process(1.0)
		assert_eq(_crossings(holder), 0, "%s sprint" % id)
		_hip(weapon)
		weapon.fire()
		weapon._process(.001)
		assert_eq(_crossings(holder), 0, "%s shot peak" % id)

## Export current imported geometry outside the normal unit suite, then run check_character_contacts.py.
## CONTACT_OUT=/tmp/character-contacts godot --headless --path . -s addons/gut/gut_cmdln.gd \
##   -gconfig= -gtest=res://tools/character_contact_export.gd -gexit
## CONTACT_IDS optionally selects comma-separated weapon IDs; otherwise every authored profile is exported.
extends GutTest


func _triples(points: PackedVector3Array) -> Array:
	var result: Array = []
	for point: Vector3 in points:
		result.append([point.x, point.y, point.z])
	return result


func _triangles(arrays: Array) -> Array:
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for index: int in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
			indices.append(index)
	var result: Array = []
	for index: int in range(0, indices.size(), 3):
		result.append([indices[index], indices[index + 1], indices[index + 2]])
	return result


func _morphed_vertices(instance: MeshInstance3D, surface: int, arrays: Array) -> PackedVector3Array:
	var mesh: ArrayMesh = instance.mesh as ArrayMesh
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var base: PackedVector3Array = vertices.duplicate()
	var shapes: Array = mesh.surface_get_blend_shape_arrays(surface)
	for shape_index: int in mesh.get_blend_shape_count():
		var weight: float = instance.get_blend_shape_value(shape_index)
		if is_zero_approx(weight):
			continue
		var shape: PackedVector3Array = shapes[shape_index][Mesh.ARRAY_VERTEX]
		for index: int in vertices.size():
			var delta: Vector3 = (
				shape[index] - base[index]
				if mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED
				else shape[index]
			)
			vertices[index] += delta * weight
	return vertices


func _skin_bindings(view: PlayerArmView) -> Dictionary:
	var transforms: Array[Transform3D] = []
	var names: Array[String] = []
	for index: int in view.mesh.skin.get_bind_count():
		var name: StringName = view.mesh.skin.get_bind_name(index)
		var bone: int = view.skeleton.find_bone(name) if not name.is_empty() else view.mesh.skin.get_bind_bone(index)
		assert_gte(bone, 0)
		transforms.append(view.skeleton.get_bone_global_pose(bone) * view.mesh.skin.get_bind_pose(index))
		names.append(view.skeleton.get_bone_name(bone))
	return {"transforms": transforms, "names": names}


func _skinned_surface(view: PlayerArmView, surface: int, frame: Transform3D, bindings: Dictionary) -> Dictionary:
	var arrays: Array = view.mesh.mesh.surface_get_arrays(surface)
	var source: PackedVector3Array = _morphed_vertices(view.mesh, surface, arrays)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / source.size()
	var vertices: PackedVector3Array = []
	var votes: Array[Dictionary] = []
	for index: int in source.size():
		var point: Vector3 = Vector3.ZERO
		var totals: Dictionary = {}
		var total_weight: float = 0.0
		for influence: int in influences:
			var slot: int = index * influences + influence
			var bind: int = bones[slot]
			var weight: float = weights[slot]
			point += (bindings.transforms[bind] as Transform3D) * source[index] * weight
			totals[bindings.names[bind]] = float(totals.get(bindings.names[bind], 0.0)) + weight
			total_weight += weight
		assert_almost_eq(total_weight, 1.0, .0001)
		vertices.append(frame * point)
		votes.append(totals)
	var triangles: Array = _triangles(arrays)
	var labels: Array[String] = []
	for triangle: Array in triangles:
		var totals: Dictionary = {}
		for index: int in triangle:
			for bone: String in votes[index]:
				totals[bone] = float(totals.get(bone, 0.0)) + float(votes[index][bone])
		var strongest: String = ""
		for bone: String in totals:
			if strongest.is_empty() or float(totals[bone]) > float(totals[strongest]):
				strongest = bone
		labels.append(strongest)
	return {
		"name": "PlayerArms/surface_%d" % surface,
		"vertices": _triples(vertices),
		"triangles": triangles,
		"labels": labels
	}


func _static_meshes(root: Node, weapon: Weapon) -> Array:
	var result: Array = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		if not instance.is_visible_in_tree() or instance.mesh == null:
			continue
		var path: String = String(root.get_path_to(instance))
		if "/FlashMesh/" in path or instance.name in [&"PlayerArms", &"FlashMesh"]:
			continue
		var frame: Transform3D = weapon.global_transform.affine_inverse() * instance.global_transform
		for surface: int in instance.mesh.get_surface_count():
			if (
				instance.mesh is ArrayMesh
				and (instance.mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES
			):
				continue
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index: int in vertices.size():
				vertices[index] = frame * vertices[index]
			result.append(
				{
					"name": path + "/surface_%d" % surface,
					"vertices": _triples(vertices),
					"triangles": _triangles(arrays)
				}
			)
	return result


func _verify_markers(view: PlayerArmView, hands: Array, weapon: Weapon) -> void:
	for side: String in ["R", "L"]:
		for tip: String in ["Index", "Thumb"]:
			var marker: Node3D = view.find_child("Grip%sTip_%s" % [tip, side], true, false) as Node3D
			var point: Vector3 = weapon.to_local(marker.global_position)
			var cap: Dictionary = {}
			for surface: Dictionary in hands:
				for entry: Array in surface.vertices:
					var vertex: Vector3 = Vector3(entry[0], entry[1], entry[2])
					if vertex.distance_to(point) < .0022:
						cap[Vector3i((vertex * 1000000).round())] = vertex
			assert_gte(cap.size(), 10, side + tip + " exported cap vertices")
			var center: Vector3 = Vector3.ZERO
			for vertex: Vector3 in cap.values():
				center += vertex
			assert_lt(
				center.distance_to(point * cap.size()) / maxf(cap.size(), 1),
				.0002,
				side + tip + " exported cap follows actual marker"
			)


func _export(holder: WeaponHolder, phase: String, directory: String) -> void:
	var weapon: Weapon = holder.current
	var view: PlayerArmView = holder.arm_view
	view.update_pose()
	await get_tree().process_frame
	view.update_pose()
	var bindings: Dictionary = _skin_bindings(view)
	var frame: Transform3D = weapon.global_transform.affine_inverse() * view.skeleton.global_transform
	var hands: Array = []
	for surface: int in view.mesh.mesh.get_surface_count():
		hands.append(_skinned_surface(view, surface, frame, bindings))
	_verify_markers(view, hands, weapon)
	var weights: Dictionary = {}
	for index: int in view.mesh.get_blend_shape_count():
		weights[view.mesh.mesh.get_blend_shape_name(index)] = view.mesh.get_blend_shape_value(index)
	var result: Dictionary = {
		"weapon": String(weapon.data.id),
		"phase": phase,
		"coordinate_frame": "weapon-local-godot",
		"morph_weights": weights,
		"arms": hands,
		"cuffs": _static_meshes(view, weapon),
		"weapon_meshes": _static_meshes(weapon.get_node("Viewmodel"), weapon)
	}
	var filename: String = directory.path_join("%s-%s.json" % [weapon.data.id, phase])
	var file: FileAccess = FileAccess.open(filename, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify(result))
	file.close()
	print("CONTACT_EXPORT ", filename)


func test_export_actual_imported_contacts() -> void:
	var directory: String = OS.get_environment("CONTACT_OUT")
	if directory.is_empty():
		directory = "/tmp/characters-contact-export"
	assert_eq(DirAccess.make_dir_recursive_absolute(directory), OK)
	var ids: Array[StringName] = PlayerArmProfiles.weapon_ids()
	var requested: String = OS.get_environment("CONTACT_IDS")
	if not requested.is_empty():
		ids.clear()
		for id: String in requested.split(","):
			ids.append(StringName(id))
	for id: StringName in ids:
		var camera: Camera3D = Camera3D.new()
		add_child(camera)
		var holder: WeaponHolder = WeaponHolder.new()
		camera.add_child(holder)
		holder.setup(null, camera)
		holder.set_process(false)
		var weapon: Weapon = holder.give(Content.weapon(id))
		weapon.set_process(false)
		holder.arm_view.set_process(false)
		weapon._process(.05)
		await _export(holder, "hip", directory)
		weapon.aiming = true
		weapon.tick(weapon.data.ads_time)
		weapon._process(.05)
		await _export(holder, "ads", directory)
		_hip(weapon)
		if id in [&"brenner_trench", &"fieldhand_lever"]:
			weapon.fire()
			weapon._process(.001)
			await _export(holder, "shot_peak", directory)
			_hip(weapon)
		weapon.instance.ammo_in_mag = 0
		assert_true(weapon.start_reload())
		weapon.tick(weapon._reload_duration * .5)
		weapon._process(.05)
		await _export(holder, "reload_mid", directory)
		camera.free()


func _hip(weapon: Weapon) -> void:
	weapon.aiming = false
	weapon.sprinting = false
	weapon.tick(1.0)
	weapon._process(1.0)

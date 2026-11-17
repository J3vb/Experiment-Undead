## Checks Prototype model scale, named mechanisms, finish imports and bounded glow vertex zones.
extends GutTest

const GUNS: Dictionary[StringName, Array] = {
	&"cryo_lance": [0.88, 0.95, ["Magazine", "Bolt", "Trigger", "Muzzle", "CondenserCoils", "PressureGauge"]],
	&"synapse": [0.8, 1.0, ["Magazine", "Bolt", "Trigger", "Muzzle", "Cabling"]],
}
const FINISH: Shader = preload("res://assets/materials/gun_finish.gdshader")


func _bounds(node: Node, transform: Transform3D, result: Array[AABB]) -> void:
	var here: Transform3D = transform * (node as Node3D).transform if node is Node3D else transform
	if node is MeshInstance3D:
		var box: AABB = here * (node as MeshInstance3D).get_aabb()
		result[0] = box if result[0].size == Vector3.ZERO else result[0].merge(box)
	for child: Node in node.get_children():
		_bounds(child, here, result)


func test_models_preserve_moving_parts_and_fit_a_rifle() -> void:
	for id: StringName in GUNS:
		var packed: PackedScene = load("res://assets/models/weapons/%s.glb" % id) as PackedScene
		assert_not_null(packed, "%s imports" % id)
		if packed == null:
			continue
		var gun: Node3D = packed.instantiate() as Node3D
		for part: String in GUNS[id][2]:
			assert_not_null(gun.find_child(part, true, false), "%s has %s" % [id, part])
		var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
		assert_lt(muzzle.position.z, -0.4, "%s fires forward" % id)
		var bounds: Array[AABB] = [AABB()]
		_bounds(gun, Transform3D.IDENTITY, bounds)
		assert_between(bounds[0].size.z, GUNS[id][0], GUNS[id][1], "%s length" % id)
		assert_lt(bounds[0].size.x, 0.16, "%s fits the player's hands" % id)
		assert_lt(bounds[0].size.y, 0.4, "%s practical rifle height" % id)
		assert_lte(gun.find_children("*", "MeshInstance3D", true, false).size(), 12, "%s draw calls" % id)
		gun.free()


func test_models_use_the_finish_shader_and_export_glow_mask() -> void:
	for id: StringName in GUNS:
		var packed: PackedScene = load("res://assets/models/weapons/%s.glb" % id) as PackedScene
		var gun: Node3D = packed.instantiate() as Node3D
		var triangles: int = 0
		var glow_vertices: int = 0
		var ordinary_vertices: int = 0
		for node: Node in gun.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for surface: int in mesh.get_surface_count():
				var material: ShaderMaterial = mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(material, "%s uses a finish material" % id)
				if material != null:
					assert_eq(material.shader, FINISH)
				var arrays: Array = mesh.surface_get_arrays(surface)
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				for color: Color in colors:
					if color.a > 0.15 and color.a < 0.5:
						glow_vertices += 1
					else:
						ordinary_vertices += 1
				triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_between(triangles, 2500, 8000, "%s detailed within budget" % id)
		assert_gt(glow_vertices, 0, "%s exports the glow zone" % id)
		assert_gt(ordinary_vertices, glow_vertices, "%s keeps its main surfaces unpainted" % id)
		var config: ConfigFile = ConfigFile.new()
		assert_eq(config.load("res://assets/models/weapons/%s.glb.import" % id), OK)
		assert_eq(config.get_value("params", "meshes/light_baking"), 3, "%s dynamic light baking" % id)
		assert_true(config.get_value("params", "meshes/generate_lods"), "%s generates LODs" % id)
		gun.free()


func test_muzzle_crowns_have_open_bores() -> void:
	for id: StringName in GUNS:
		var packed: PackedScene = load("res://assets/models/weapons/%s.glb" % id) as PackedScene
		var gun: Node3D = packed.instantiate() as Node3D
		var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
		var ray_start: Vector3 = muzzle.position + Vector3.FORWARD * 0.01
		assert_false(
			MeshChecks.blocks_segment(gun, ray_start, ray_start + Vector3.BACK * 0.04), "%s muzzle bore stays open" % id
		)
		gun.free()

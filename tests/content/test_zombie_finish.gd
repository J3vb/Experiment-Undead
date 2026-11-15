## Zombie finishes preserve their palette and material budget; only the Belly
## instance changes the shared glow response, and rarity cannot recolour enemies.
extends GutTest

const IMPORTER: GDScript = preload("res://tools/assets/zombie_finish_import.gd")
const SHADER: Shader = preload("res://assets/materials/zombie_finish.gdshader")
const PALETTE: Dictionary[String, String] = {
	"ZombieSkinHead": "#B9C2B0",
	"ZombieSkin": "#8E9887",
	"ZombieSkinBloater": "#4A5446",
	"ZombieSkinDecay": "#5A0E0C",
	"ZombieClothCoat": "#8A918C",
	"ZombieClothShirt": "#2F393B",
	"ZombieClothTrousers": "#1C2122",
	"ZombieShoe": "#0E1010",
	"ZombieGlow": "#8DFF3A",
}


func _model(kind: String) -> Node3D:
	var model: Node3D = (load("res://assets/models/zombies/%s.glb" % kind) as PackedScene).instantiate() as Node3D
	autofree(model)
	return model


func test_all_zombie_surfaces_retain_palette_and_shared_materials() -> void:
	for kind: String in ["shambler", "crawler", "bloater"]:
		var model: Node3D = _model(kind)
		var materials: Dictionary[String, Material] = {}
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for surface: int in mesh.get_surface_count():
				var material: ShaderMaterial = mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(material, kind + " has a procedural finish")
				if material == null:
					continue
				assert_same(material.shader, SHADER)
				assert_true(PALETTE.has(material.resource_name), kind + " uses only palette materials")
				if PALETTE.has(material.resource_name):
					var color: Color = material.get_shader_parameter(&"albedo")
					var expected: Color = Color(PALETTE[material.resource_name])
					for channel: int in 4:
						assert_almost_eq(color[channel], expected[channel], 0.002, material.resource_name)
				if materials.has(material.resource_name):
					assert_same(material, materials[material.resource_name], "repeated finishes remain shared")
				materials[material.resource_name] = material
				assert_null(material.next_pass, "no extra horde draw pass")
		assert_lte(materials.size(), 8, kind + " keeps the material budget")


func test_head_and_decay_have_their_own_surface_response() -> void:
	for mat_name: String in PALETTE:
		var source: StandardMaterial3D = StandardMaterial3D.new()
		source.resource_name = mat_name
		source.albedo_color = Color(PALETTE[mat_name])
		source.roughness = 0.73
		var result: ShaderMaterial = IMPORTER.finish_material(source)
		assert_eq(result.get_shader_parameter(&"albedo"), source.albedo_color)
		assert_eq(result.get_shader_parameter(&"roughness"), source.roughness)
		assert_eq(result.get_shader_parameter(&"pale_head"), mat_name == "ZombieSkinHead")
		assert_eq(result.get_shader_parameter(&"decay"), mat_name == "ZombieSkinDecay")
		assert_between(result.get_shader_parameter(&"finish"), 7, 10)
		if mat_name != "ZombieGlow":
			assert_null(result.get_shader_parameter(&"emission_strength"), "plain surfaces never get emission")


func test_only_belly_changes_the_shared_eye_glow_response() -> void:
	for kind: String in ["shambler", "crawler", "bloater"]:
		var model: Node3D = _model(kind)
		var eye: MeshInstance3D = model.find_child("EyeL", true, false) as MeshInstance3D
		var eye_material: ShaderMaterial = eye.mesh.surface_get_material(0) as ShaderMaterial
		assert_gt(float(eye_material.get_shader_parameter(&"emission_strength")), 0.0)
		assert_eq(eye.get_instance_shader_parameter(&"belly"), false)
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var instance: MeshInstance3D = node as MeshInstance3D
			assert_eq(instance.get_instance_shader_parameter(&"belly"), node.name == &"Belly")
		if kind == "bloater":
			var belly: MeshInstance3D = model.find_child("Belly", true, false) as MeshInstance3D
			assert_same(belly.mesh.surface_get_material(0), eye_material, "belly needs no ninth material")


func test_zombie_shader_has_no_rarity_dye_or_texture_inputs() -> void:
	var forbidden: Array[String] = ["dye_main", "dye_accent", "trim_color", "glow_color", "glow_strength", "flicker"]
	var parameters: Array = SHADER.get_shader_uniform_list()
	var names: Array[String] = []
	for parameter: Dictionary in parameters:
		names.append(String(parameter["name"]))
		assert_false(String(parameter["name"]) in forbidden, "player appearance cannot change zombie values")
		assert_ne(int(parameter["type"]), TYPE_OBJECT, "finish has no texture sampler")
	for required: String in [
		"albedo", "finish", "roughness", "pale_head", "decay", "emission_color", "emission_strength"
	]:
		assert_has(names, required, "shader reflection exposes the finish controls")


func test_import_preserves_intrinsic_emission() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	source.resource_name = "ZombieGlow"
	source.albedo_color = Color("#8DFF3A")
	source.emission_enabled = true
	source.emission = source.albedo_color
	source.emission_energy_multiplier = 0.6
	var result: ShaderMaterial = IMPORTER.finish_material(source)
	assert_eq(result.get_shader_parameter(&"emission_color"), source.emission)
	assert_eq(result.get_shader_parameter(&"emission_strength"), source.emission_energy_multiplier)
	assert_eq(result.get_shader_parameter(&"finish"), 10)


func test_scene_roundtrip_keeps_shared_finish_and_belly_instance_flag() -> void:
	var model: Node3D = _model("bloater")
	var eye: MeshInstance3D = model.find_child("EyeL", true, false) as MeshInstance3D
	var previous: Material = eye.mesh.surface_get_material(0)
	var packed: PackedScene = PackedScene.new()
	assert_eq(packed.pack(model), OK)
	var restored: Node3D = packed.instantiate() as Node3D
	autofree(restored)
	eye = restored.find_child("EyeL", true, false) as MeshInstance3D
	assert_same(eye.mesh.surface_get_material(0), previous)
	var belly: MeshInstance3D = restored.find_child("Belly", true, false) as MeshInstance3D
	assert_same(belly.mesh.surface_get_material(0), previous)
	assert_eq(belly.get_instance_shader_parameter(&"belly"), true)


func test_unknown_and_missing_materials_report_errors() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	source.resource_name = "UnmappedZombieFinish"
	var result: ShaderMaterial = IMPORTER.finish_material(source)
	assert_eq(result.get_shader_parameter(&"albedo"), source.albedo_color)
	assert_push_error("zombie material 'UnmappedZombieFinish' has no finish")
	result = IMPORTER.finish_material(null)
	assert_eq(result.get_shader_parameter(&"albedo"), Color.WHITE)
	assert_push_error("zombie material '' has no finish")

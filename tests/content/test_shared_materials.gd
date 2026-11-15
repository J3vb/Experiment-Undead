## Shared material setup keeps each surface's authored look and independent noise.
extends GutTest

const MATERIALS: String = "res://levels/materials/"
const ROUND_TRIP: String = "user://test_shared_material_"
const NOISE_VALUES: Dictionary = {
	"brick": [Color(0.5, 0.27, 0.2, 1.0), 0.12, 8.0, 0.0, 0.92, 0.3],
	"concrete": [Color(0.55, 0.55, 0.53, 1.0), 0.06, 3.0, 0.0, 0.9, 0.35],
	"ground": [Color(0.32, 0.28, 0.22, 1.0), 0.03, 6.0, 0.0, 0.95, 0.15],
	"rust": [Color(0.35, 0.18, 0.1, 1.0), 0.1, 5.0, 0.4, 0.7, 0.4],
	"wood": [Color(0.45, 0.3, 0.17, 1.0), 0.08, 4.0, 0.0, 0.85, 0.5],
}
const GRIME_VALUES: Dictionary = {
	"ceiling_stained":
	{
		"base_color": Color(0.36, 0.37, 0.36, 1.0),
		"roughness": 0.9,
		"normal_strength": 0.3,
		"stains": 0.55,
	},
	"panel_paint":
	{
		"base_color": Color(0.37, 0.43, 0.41, 1.0),
		"roughness": 0.75,
		"streaks": 0.55,
		"floor_dirt": 0.5,
	},
	"panel_trim":
	{
		"base_color": Color(0.22, 0.25, 0.25, 1.0),
		"roughness": 0.85,
		"streaks": 0.3,
		"floor_dirt": 0.6,
	},
}

var _saved_paths: Array[String] = []


func after_each() -> void:
	for path: String in _saved_paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_saved_paths.clear()


func test_noise_material_surface_values_are_preserved() -> void:
	for name: String in NOISE_VALUES:
		var material: StandardMaterial3D = load(MATERIALS + name + ".tres") as StandardMaterial3D
		var expected: Array = NOISE_VALUES[name]
		assert_not_null(material, name)
		if material == null:
			continue
		assert_eq(material.get_script().resource_path, MATERIALS + "noise_material.gd", name)
		assert_eq(material.albedo_color, expected[0], name)
		assert_almost_eq(material.metallic, float(expected[3]), 0.000001, name)
		assert_almost_eq(material.roughness, float(expected[4]), 0.000001, name)
		assert_eq(material.uv1_scale, Vector3.ONE * float(expected[5]), name)
		assert_true(material.uv1_triplanar, name)
		assert_true(material.normal_enabled, name)


func test_noise_textures_share_one_generator_per_material_without_cross_surface_mutation() -> void:
	var generators: Array[Noise] = []
	for name: String in NOISE_VALUES:
		var material: StandardMaterial3D = load(MATERIALS + name + ".tres") as StandardMaterial3D
		var expected: Array = NOISE_VALUES[name]
		var albedo: NoiseTexture2D = material.albedo_texture as NoiseTexture2D
		var normal: NoiseTexture2D = material.normal_texture as NoiseTexture2D
		_check_noise_texture(albedo, false, 8.0)
		_check_noise_texture(normal, true, float(expected[2]))
		if albedo == null or normal == null:
			continue
		assert_same(albedo.noise, normal.noise, name + " uses one noise generator for both maps")
		var noise: FastNoiseLite = albedo.noise as FastNoiseLite
		assert_not_null(noise, name)
		if noise == null:
			continue
		assert_almost_eq(noise.frequency, float(expected[1]), 0.000001, name)
		assert_eq(noise.fractal_octaves, 5, name)
		assert_false(generators.has(noise), name + " keeps its own frequency")
		generators.append(noise)


func _check_noise_texture(texture: NoiseTexture2D, normal_map: bool, strength: float) -> void:
	assert_not_null(texture)
	if texture == null:
		return
	assert_eq(texture.width, 512)
	assert_eq(texture.height, 512)
	assert_true(texture.seamless)
	assert_eq(texture.as_normal_map, normal_map)
	assert_almost_eq(texture.bump_strength, strength, 0.000001)


func test_grime_materials_share_shader_and_textures_but_keep_surface_parameters() -> void:
	var shader: Shader = load(MATERIALS + "grime_shader.tres") as Shader
	var source: Shader = load(MATERIALS + "grime.gdshader") as Shader
	var noise: Texture2D = load(MATERIALS + "grime_noise.tres") as Texture2D
	var normal: Texture2D = load(MATERIALS + "grime_normal.tres") as Texture2D
	assert_eq(shader.code, source.code)
	for name: String in GRIME_VALUES:
		var material: ShaderMaterial = load(MATERIALS + name + ".tres") as ShaderMaterial
		assert_not_null(material, name)
		if material == null:
			continue
		assert_same(material.shader, shader, name)
		assert_same(material.shader.get_default_texture_parameter("noise"), noise, name)
		assert_same(material.shader.get_default_texture_parameter("detail_normal"), normal, name)
		var expected: Dictionary = GRIME_VALUES[name]
		for parameter: String in expected:
			var actual: Variant = material.get_shader_parameter(parameter)
			if expected[parameter] is float:
				assert_almost_eq(float(actual), float(expected[parameter]), 0.000001, name + ": " + parameter)
			else:
				assert_eq(actual, expected[parameter], name + ": " + parameter)


func _round_trip(resource: Resource, label: String) -> Resource:
	var path: String = ROUND_TRIP + label + ".tres"
	var result: Error = ResourceSaver.save(resource, path)
	assert_eq(result, OK, label + " saves")
	if result != OK:
		return null
	_saved_paths.append(path)
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)


func test_noise_material_save_reload_reconstructs_maps_and_preserves_surface_values() -> void:
	for name: String in NOISE_VALUES:
		var material: StandardMaterial3D = load(MATERIALS + name + ".tres") as StandardMaterial3D
		var copy: StandardMaterial3D = _round_trip(material, name) as StandardMaterial3D
		assert_not_null(copy, name)
		if copy == null:
			continue
		for property: String in [
			"albedo_color", "metallic", "roughness", "uv1_scale", "uv1_triplanar", "normal_enabled"
		]:
			assert_eq(copy.get(property), material.get(property), name + ": " + property)
		var albedo: NoiseTexture2D = copy.albedo_texture as NoiseTexture2D
		var normal: NoiseTexture2D = copy.normal_texture as NoiseTexture2D
		_check_noise_texture(albedo, false, 8.0)
		_check_noise_texture(normal, true, float(NOISE_VALUES[name][2]))
		assert_same(albedo.noise, normal.noise, name)
		assert_ne(albedo, material.albedo_texture, name + " rebuilds its maps")
		assert_almost_eq((albedo.noise as FastNoiseLite).frequency, float(NOISE_VALUES[name][1]), 0.000001, name)
		assert_eq((albedo.noise as FastNoiseLite).fractal_octaves, 5, name)
		var serialized: String = FileAccess.get_file_as_string(ROUND_TRIP + name + ".tres")
		assert_false(serialized.contains("NoiseTexture2D"), name + " stores parameters rather than owned maps")


func test_grime_material_save_reload_retains_shared_bindings_and_authored_parameters() -> void:
	var shader: Shader = load(MATERIALS + "grime_shader.tres") as Shader
	for name: String in GRIME_VALUES:
		var material: ShaderMaterial = load(MATERIALS + name + ".tres") as ShaderMaterial
		var copy: ShaderMaterial = _round_trip(material, name) as ShaderMaterial
		assert_not_null(copy, name)
		if copy == null:
			continue
		assert_same(copy.shader, shader, name)
		var expected: Dictionary = GRIME_VALUES[name]
		for parameter: String in expected:
			assert_eq(
				copy.get_shader_parameter(parameter), material.get_shader_parameter(parameter), name + ": " + parameter
			)
		assert_same(copy.shader.get_default_texture_parameter("noise"), load(MATERIALS + "grime_noise.tres"), name)
		assert_same(
			copy.shader.get_default_texture_parameter("detail_normal"), load(MATERIALS + "grime_normal.tres"), name
		)
		var serialized: String = FileAccess.get_file_as_string(ROUND_TRIP + name + ".tres")
		assert_true(serialized.contains("grime_shader.tres"), name)
		assert_false(serialized.contains("grime.gdshader"), name)
		assert_false(serialized.contains("grime_noise.tres"), name)
		assert_false(serialized.contains("grime_normal.tres"), name)


func test_shared_grime_shader_save_reload_restores_code_and_default_textures() -> void:
	var shader: Shader = load(MATERIALS + "grime_shader.tres") as Shader
	var copy: Shader = _round_trip(shader, "shader") as Shader
	assert_not_null(copy)
	if copy == null:
		return
	assert_eq(copy.code, (load(MATERIALS + "grime.gdshader") as Shader).code)
	assert_same(copy.get_default_texture_parameter("noise"), load(MATERIALS + "grime_noise.tres"))
	assert_same(copy.get_default_texture_parameter("detail_normal"), load(MATERIALS + "grime_normal.tres"))
	var serialized: String = FileAccess.get_file_as_string(ROUND_TRIP + "shader.tres")
	assert_false(serialized.contains("shader_type spatial"), "the source shader remains the only copy of its code")


func test_shared_grime_shader_refreshes_source_edits_and_keeps_default_textures() -> void:
	var source: Shader = load(MATERIALS + "grime.gdshader") as Shader
	var shader: Shader = load(MATERIALS + "grime_shader.tres") as Shader
	var original: String = source.code
	var edited: String = original + "\n// Live preview edit.\n"
	source.code = edited
	await get_tree().process_frame
	assert_eq(shader.code, edited, "editing the canonical shader refreshes shared materials")
	assert_same(shader.get_default_texture_parameter("noise"), load(MATERIALS + "grime_noise.tres"))
	assert_same(shader.get_default_texture_parameter("detail_normal"), load(MATERIALS + "grime_normal.tres"))
	source.code = original
	await get_tree().process_frame
	assert_eq(shader.code, original, "restoring the source restores all shared materials")

## Forces the procedural shader to compile and checks its imported material contract.
extends GutTest

const SHADER: Shader = preload("res://assets/materials/gear.gdshader")


func test_gear_shader_compiles_with_albedo_and_finish_uniforms() -> void:
	var uniforms: Array = SHADER.get_shader_uniform_list()
	var types: Dictionary[StringName, int] = {}
	for uniform: Dictionary in uniforms:
		types[StringName(uniform.name)] = uniform.type
	assert_eq(types.get(&"albedo"), TYPE_COLOR)
	assert_eq(types.get(&"finish"), TYPE_INT)
	assert_push_error_count(0, "gear shader compiles without errors")

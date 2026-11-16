## ScopeLens survives the dedicated server export, where materials are stripped.
extends GutTest


func test_lens_without_material_disables_itself() -> void:
	var lens: ScopeLens = ScopeLens.new()
	add_child_autofree(lens)
	assert_false(lens.is_processing(), "no material means nothing to render")
	assert_false(lens.is_rendering())


func test_lens_with_material_feeds_the_viewport_texture() -> void:
	var lens: ScopeLens = ScopeLens.new()
	var material: ShaderMaterial = ShaderMaterial.new()
	lens.material_override = material
	add_child_autofree(lens)
	assert_true(lens.is_processing())
	assert_eq(material.get_shader_parameter(&"view"), lens.viewport.get_texture())

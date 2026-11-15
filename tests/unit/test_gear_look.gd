## Per-instance looks reach every geometry node and leave shared materials and data unchanged.
extends GutTest


func test_apply_sets_all_uniforms_on_root_and_nested_geometry() -> void:
	var root: MeshInstance3D = _mesh()
	var branch: Node3D = Node3D.new()
	var nested: MeshInstance3D = _mesh()
	root.add_child(branch)
	branch.add_child(nested)
	var look: RarityLook = RarityLook.new()
	look.trim_color = Color("ff8a1c")
	look.glow_strength = 2.0
	look.pulse_seconds = 4.0
	look.flicker = true
	var main: Color = Color("5f6d68")
	var accent: Color = Color("cdeee8")
	GearLook.apply(root, look, main, accent)
	for geometry: GeometryInstance3D in [root, nested]:
		assert_eq(geometry.get_instance_shader_parameter(&"dye_main"), main)
		assert_eq(geometry.get_instance_shader_parameter(&"dye_accent"), accent)
		assert_eq(geometry.get_instance_shader_parameter(&"trim_color"), look.trim_color)
		assert_eq(geometry.get_instance_shader_parameter(&"glow_color"), look.trim_color)
		assert_eq(geometry.get_instance_shader_parameter(&"glow_strength"), 2.0)
		assert_eq(geometry.get_instance_shader_parameter(&"pulse_seconds"), 4.0)
		assert_eq(geometry.get_instance_shader_parameter(&"flicker"), true)
	root.free()


func test_common_and_uncommon_clear_previous_glow_and_motion() -> void:
	var mesh: MeshInstance3D = _mesh()
	var prototype: RarityLook = load("res://content/looks/rarity/prototype.tres") as RarityLook
	for rarity: String in ["common", "uncommon"]:
		GearLook.apply(mesh, prototype, Color.WHITE, Color.WHITE)
		var look: RarityLook = load("res://content/looks/rarity/%s.tres" % rarity) as RarityLook
		GearLook.apply(mesh, look, Color.WHITE, Color.WHITE)
		assert_eq(mesh.get_instance_shader_parameter(&"glow_strength"), 0.0, rarity)
		assert_eq(mesh.get_instance_shader_parameter(&"pulse_seconds"), 0.0, rarity)
		assert_eq(mesh.get_instance_shader_parameter(&"flicker"), false, rarity)
	mesh.free()


func test_apply_keeps_other_instances_and_shared_resources_unchanged() -> void:
	var first: MeshInstance3D = _mesh()
	var second: MeshInstance3D = _mesh()
	second.mesh = first.mesh
	var common: RarityLook = load("res://content/looks/rarity/common.tres") as RarityLook
	var legendary: RarityLook = load("res://content/looks/rarity/legendary.tres") as RarityLook
	GearLook.apply(first, common, Color.WHITE, Color.WHITE)
	GearLook.apply(second, legendary, Color("5f6d68"), Color("cdeee8"))
	assert_eq(first.get_instance_shader_parameter(&"trim_color"), common.trim_color)
	assert_eq(first.get_instance_shader_parameter(&"glow_strength"), 0.0)
	assert_eq(first.get_instance_shader_parameter(&"dye_main"), Color.WHITE)
	assert_eq(second.get_instance_shader_parameter(&"glow_strength"), 2.0)
	assert_same(first.mesh.surface_get_material(0), second.mesh.surface_get_material(0))
	assert_eq(common.glow_strength, 0.0)
	assert_eq(legendary.trim_color.to_html(false), "ff8a1c")
	assert_eq(legendary.pulse_seconds, 4.0)
	first.free()
	second.free()


func _mesh() -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://assets/materials/gear.gdshader") as Shader
	box.material = material
	mesh.mesh = box
	return mesh

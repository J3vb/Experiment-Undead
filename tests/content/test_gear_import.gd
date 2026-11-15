## Rigid gear keeps its paint masks, shared shader finishes and dynamic lighting.
extends GutTest

const IMPORTER: GDScript = preload("res://tools/assets/gear_import.gd")
const SHADER: Shader = preload("res://assets/materials/gear.gdshader")
const GLASS_SHADER: Shader = preload("res://assets/materials/gear_glass.gdshader")
const NAMES: Array[String] = [
	"charm_dog_tags",
	"charm_vial",
	"charm_keycard",
	"charm_dosimeter",
	"charm_coin",
	"implant_reflex",
	"implant_lung",
	"implant_spine",
	"implant_ocular",
	"implant_relay",
]


func test_imported_gear_uses_zone_shader_and_preserves_vertex_colors() -> void:
	for model_name: String in NAMES:
		var path: String = "res://assets/models/gear/%s.glb" % model_name
		var packed: PackedScene = load(path) as PackedScene
		assert_not_null(packed, model_name)
		if packed == null:
			continue
		var scene: Node = packed.instantiate()
		for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
			_check_surfaces((node as MeshInstance3D).mesh, model_name)
		scene.free()


func _check_surfaces(mesh: Mesh, model_name: String) -> void:
	for index: int in mesh.get_surface_count():
		assert_true(bool(mesh.surface_get_format(index) & Mesh.ARRAY_FORMAT_COLOR), model_name)
		var material: ShaderMaterial = mesh.surface_get_material(index) as ShaderMaterial
		assert_not_null(material, model_name)
		if material != null:
			if material.resource_name == "GearGlass":
				assert_has(["charm_vial", "implant_ocular"], model_name, "glass belongs only to optical gear")
				assert_eq(material.shader, GLASS_SHADER, model_name)
			else:
				if material.resource_name == "GearLiquid":
					assert_eq(model_name, "charm_vial", "only the specimen contains liquid")
				assert_eq(material.shader, SHADER, model_name)
				assert_has(IMPORTER.FINISHES, material.resource_name, model_name)


func test_all_gear_imports_use_dynamic_light_baking_and_lods() -> void:
	for model_name: String in NAMES:
		var config: ConfigFile = ConfigFile.new()
		var path: String = "res://assets/models/gear/%s.glb.import" % model_name
		assert_eq(config.load(path), OK, model_name)
		assert_eq(config.get_value("params", "meshes/light_baking"), 3, model_name)
		assert_eq(config.get_value("params", "meshes/generate_lods"), true, model_name)
		assert_eq(config.get_value("params", "import_script/path"), "res://tools/assets/gear_import.gd", model_name)


func test_rigid_finishes_preserve_albedo_and_select_the_shared_finish() -> void:
	for finish_name: String in ["GearPlate", "GearPolymer", "GearRubber"]:
		var source: StandardMaterial3D = StandardMaterial3D.new()
		source.resource_name = finish_name
		source.albedo_color = Color("5F6D68")
		var material: ShaderMaterial = IMPORTER.finish_material(source) as ShaderMaterial
		assert_eq(material.shader, SHADER)
		assert_eq(material.get_shader_parameter(&"albedo"), source.albedo_color)
		assert_eq(material.get_shader_parameter(&"finish"), IMPORTER.FINISHES[finish_name])


func test_glass_is_present_on_the_vial_and_both_ocular_pieces() -> void:
	var expected: Dictionary[String, Array] = {"charm_vial": ["Body"], "implant_ocular": ["Module", "Port"]}
	for model_name: String in expected:
		var packed: PackedScene = load("res://assets/models/gear/%s.glb" % model_name) as PackedScene
		var model: Node3D = packed.instantiate() as Node3D
		autofree(model)
		var pieces: Array[String] = []
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for surface: int in mesh.get_surface_count():
				var material: ShaderMaterial = mesh.surface_get_material(surface) as ShaderMaterial
				if material == null or material.resource_name != "GearGlass":
					continue
				pieces.append(node.name)
				assert_eq(material.shader, GLASS_SHADER)
				var tint: Color = material.get_shader_parameter(&"albedo")
				assert_true(tint.is_equal_approx(Color(Color("#CDEEE8"), 0.14)), "glass keeps the palette tint")
				var colors: PackedColorArray = mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				for color: Color in colors:
					assert_gte(color.a, 0.66, "clear glass must not replace trim or glowing surfaces")
		pieces.sort()
		assert_eq(pieces, expected[model_name], model_name + " needs real glass surfaces")


func test_glass_import_preserves_tint_and_keeps_opaque_finishes_separate() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	source.resource_name = "GearGlass"
	source.albedo_color = Color("#CDEEE8")
	var material: ShaderMaterial = IMPORTER.finish_material(source)
	assert_eq(material.shader, GLASS_SHADER)
	assert_eq(material.resource_name, "GearGlass")
	assert_eq(material.get_shader_parameter(&"albedo"), source.albedo_color)
	assert_null(material.get_shader_parameter(&"finish"), "glass does not use an opaque finish")
	var instances: Array[String] = []
	for uniform: Dictionary in GLASS_SHADER.get_shader_uniform_list():
		instances.append(uniform["name"])
	assert_has(instances, "albedo")
	assert_push_error_count(0)


func test_gear_look_updates_mixed_glass_and_opaque_mesh_without_changing_materials() -> void:
	var mesh: ArrayMesh = ArrayMesh.new()
	var source_mesh: BoxMesh = BoxMesh.new()
	var originals: Array[ShaderMaterial] = []
	for finish_name: String in ["GearGlass", "GearPlate"]:
		var source: StandardMaterial3D = StandardMaterial3D.new()
		source.resource_name = finish_name
		var material: ShaderMaterial = IMPORTER.finish_material(source)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source_mesh.surface_get_arrays(0))
		mesh.surface_set_material(originals.size(), material)
		originals.append(material)
	var piece: MeshInstance3D = MeshInstance3D.new()
	piece.mesh = mesh
	autofree(piece)
	var look: RarityLook = load("res://content/looks/rarity/legendary.tres") as RarityLook
	var dye: Color = Color("#5F6D68")
	GearLook.apply(piece, look, dye, Color.WHITE)
	assert_eq(piece.get_instance_shader_parameter(&"dye_main"), dye)
	assert_eq(piece.get_instance_shader_parameter(&"trim_color"), look.trim_color)
	assert_eq(piece.get_instance_shader_parameter(&"glow_strength"), look.glow_strength)
	for index: int in originals.size():
		assert_same(mesh.surface_get_material(index), originals[index])
	assert_eq(originals[0].shader, GLASS_SHADER)
	assert_eq(originals[1].shader, SHADER)
	assert_push_error_count(0)


func test_specimen_liquid_uses_a_polished_finish_and_keeps_its_own_glow_zones() -> void:
	var model: Node3D = (load("res://assets/models/gear/charm_vial.glb") as PackedScene).instantiate() as Node3D
	autofree(model)
	var body: Mesh = (model.find_child("Body", true, false) as MeshInstance3D).mesh
	var liquid_surfaces: int = 0
	for index: int in body.get_surface_count():
		var material: ShaderMaterial = body.surface_get_material(index) as ShaderMaterial
		if material == null or material.resource_name != "GearLiquid":
			continue
		liquid_surfaces += 1
		assert_eq(material.shader, SHADER)
		assert_eq(material.get_shader_parameter(&"finish"), 6, "liquid uses the polished optical finish")
		var tint: Color = material.get_shader_parameter(&"albedo")
		assert_true(tint.is_equal_approx(Color("#8DFF3A")), "specimen keeps the experiment colour")
		var colors: PackedColorArray = body.surface_get_arrays(index)[Mesh.ARRAY_COLOR]
		var glow_vertices: int = 0
		var main_vertices: int = 0
		for color: Color in colors:
			glow_vertices += 1 if color.a < 0.01 else 0
			main_vertices += 1 if color.a > 0.99 else 0
		assert_gt(glow_vertices, 0, "meniscus has a bounded glow zone")
		assert_gt(main_vertices, 0, "the bulk of the specimen remains a solid main-zone surface")
	assert_eq(liquid_surfaces, 1, "one liquid surface shares the regular gear zone shader")

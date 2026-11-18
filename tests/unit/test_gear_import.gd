## Gear import maps every supported Blender material and reports unknown finishes.
extends GutTest

const IMPORTER: GDScript = preload("res://tools/assets/gear_import.gd")
const FINISHES: Dictionary[String, int] = {
	"BodySuit": 0,
	"BodyKnit": 5,
	"BodyRubber": 4,
	"GearFabric": 0,
	"GearWebbing": 1,
	"GearPlate": 2,
	"GearPolymer": 3,
	"GearRubber": 4,
	"ZombieSkin": 7,
	"ZombieCloth": 8,
	"ZombieShoe": 9,
	"ZombieGlow": 10,
}


func test_supported_materials_keep_their_colour_and_select_the_expected_finish() -> void:
	for mat_name: String in FINISHES:
		var source: StandardMaterial3D = StandardMaterial3D.new()
		source.resource_name = mat_name
		source.albedo_color = Color("#5F6D68")
		var material: ShaderMaterial = IMPORTER.finish_material(source)
		assert_eq(material.shader.resource_path, "res://assets/materials/gear.gdshader")
		assert_eq(material.resource_name, mat_name)
		assert_eq(material.get_shader_parameter(&"finish"), FINISHES[mat_name])
		assert_eq(material.get_shader_parameter(&"albedo"), source.albedo_color)
	assert_push_error_count(0)


func test_player_body_keeps_its_baked_maps() -> void:
	var model: Node3D = (load("res://assets/models/characters/player.glb") as PackedScene).instantiate() as Node3D
	autofree(model)
	var names: Array[String] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var material: BaseMaterial3D = mesh.surface_get_material(surface) as BaseMaterial3D
			assert_not_null(material, "body surfaces keep their baked standard material")
			if material == null:
				continue
			assert_not_null(material.albedo_texture, material.resource_name + " has its colour map")
			assert_not_null(material.normal_texture, material.resource_name + " has its normal map")
			assert_false(material.vertex_color_use_as_albedo, "vertex colour holds AO and zones, not colour")
			names.append(material.resource_name)
	names.sort()
	assert_eq(names, ["BodyCloth", "BodyHair", "BodyRubber", "BodySkin"])


func test_unknown_material_reports_the_name_and_uses_fabric() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	source.resource_name = "UnmappedPlate"
	var material: ShaderMaterial = IMPORTER.finish_material(source)
	assert_eq(material.get_shader_parameter(&"finish"), 0)
	assert_push_error("gear material 'UnmappedPlate' has no finish")


func test_missing_material_reports_an_error_and_uses_plain_fabric() -> void:
	var material: ShaderMaterial = IMPORTER.finish_material(null)
	assert_eq(material.get_shader_parameter(&"finish"), 0)
	assert_eq(material.get_shader_parameter(&"albedo"), Color.WHITE)
	assert_push_error("gear material '' has no finish")


func test_zombie_variants_preserve_the_head_and_clothing_palette() -> void:
	var variants: Dictionary[String, Color] = {
		"ZombieSkinHead": Color("#B9C2B0"),
		"ZombieSkin": Color("#8E9887"),
		"ZombieSkinBloater": Color("#4A5446"),
		"ZombieClothCoat": Color("#8A918C"),
		"ZombieClothShirt": Color("#2F393B"),
		"ZombieClothTrousers": Color("#1C2122"),
		"ZombieShoe": Color("#0E1010"),
	}
	for mat_name: String in variants:
		var source: StandardMaterial3D = StandardMaterial3D.new()
		source.resource_name = mat_name
		source.albedo_color = variants[mat_name]
		var material: ShaderMaterial = IMPORTER.finish_material(source)
		assert_eq(material.get_shader_parameter(&"albedo"), variants[mat_name])
		assert_between(material.get_shader_parameter(&"finish"), 7, 9)
		assert_null(material.get_shader_parameter(&"emission_strength"), "only bio-green finishes emit")
	assert_push_error_count(0)


func test_zombie_glow_uses_source_emission_without_requiring_a_rarity_zone() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	source.resource_name = "ZombieGlow"
	source.albedo_color = Color("#8DFF3A")
	source.emission_enabled = true
	source.emission = source.albedo_color * 0.6
	source.emission_energy_multiplier = 1.4
	var material: ShaderMaterial = IMPORTER.finish_material(source)
	assert_eq(material.get_shader_parameter(&"finish"), 10)
	assert_almost_eq(material.get_shader_parameter(&"emission_strength"), 1.4, 0.001)
	assert_eq(material.get_shader_parameter(&"emission_color"), source.emission)
	assert_eq(material.get_shader_parameter(&"albedo"), source.albedo_color)
	assert_push_error_count(0)


func test_zombie_imports_use_only_zombie_finishes_and_main_paint_zones() -> void:
	for kind: String in ["shambler", "crawler", "bloater"]:
		var packed: PackedScene = load("res://assets/models/zombies/%s.glb" % kind) as PackedScene
		assert_not_null(packed, kind + " imports")
		if packed == null:
			continue
		var model: Node3D = packed.instantiate() as Node3D
		autofree(model)
		var glow_surfaces: int = 0
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for surface: int in mesh.get_surface_count():
				var material: ShaderMaterial = mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(material, kind + " uses the zombie finish shader")
				if material == null:
					continue
				assert_eq(material.shader.resource_path, "res://assets/materials/zombie_finish.gdshader")
				var finish: int = material.get_shader_parameter(&"finish")
				assert_between(finish, 7, 10, kind + " cannot acquire a player finish")
				if finish == 10:
					glow_surfaces += 1
					assert_gt(float(material.get_shader_parameter(&"emission_strength")), 0.0)
				var colors: PackedColorArray = mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				assert_gt(colors.size(), 0, kind + " retains baked AO and main paint zones")
				for color: Color in colors:
					assert_almost_eq(color.a, 1.0, 0.001, kind + " has no rarity or dye zones")
		assert_gte(glow_surfaces, 2, kind + " eyes have intrinsic bio-green emission")


func test_vest_imports_share_four_finishes_across_shell_and_first_person_cuffs() -> void:
	for frame: String in ["light", "medium", "heavy"]:
		var packed: PackedScene = load("res://assets/models/gear/vest_%s.glb" % frame) as PackedScene
		assert_not_null(packed, frame + " vest imports")
		if packed == null:
			continue
		var model: Node3D = packed.instantiate() as Node3D
		autofree(model)
		var materials: Array[Material] = []
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for surface: int in mesh.get_surface_count():
				var material: Material = mesh.surface_get_material(surface)
				assert_true(material is ShaderMaterial, "all imported finishes use the gear shader")
				if not materials.has(material):
					materials.append(material)
		assert_eq(materials.size(), 4, frame + " Shell and both FP cuffs reuse four finish resources")

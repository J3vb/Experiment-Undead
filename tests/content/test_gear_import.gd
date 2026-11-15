## Rigid gear keeps its paint masks, shared shader finishes and dynamic lighting.
extends GutTest

const IMPORTER: GDScript = preload("res://tools/assets/gear_import.gd")
const SHADER: Shader = preload("res://assets/materials/gear.gdshader")
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

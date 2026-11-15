## Gear import maps every supported Blender material and reports unknown finishes.
extends GutTest

const IMPORTER: GDScript = preload("res://tools/assets/gear_import.gd")
const FINISHES: Dictionary[String, int] = {
	"BodySuit": 0,
	"BodyKnit": 5,
	"BodyRubber": 4,
	"BodyLens": 6,
	"GearFabric": 0,
	"GearWebbing": 1,
	"GearPlate": 2,
	"GearPolymer": 3,
	"GearRubber": 4,
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

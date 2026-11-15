## Checks the gun finish from tools/assets/gun_finish_import.gd: every gun surface
## except optic glass uses the shared gun shader with the colour, finish and knurl
## its Blender material asked for, and the shader multiplies in the baked shading.
extends GutTest

const GUNS: Array[String] = ["rifle_ar", "kestrel_smg", "talon_dmr", "shotgun_brenner"]
const SHADER: String = "res://assets/materials/gun_finish.gdshader"
const IMPORTER: GDScript = preload("res://tools/assets/gun_finish_import.gd")
const KNURLED: Dictionary[String, String] = {
	"rifle_ar": "GunMetalKnurled",
	"kestrel_smg": "MatteBlackKnurled",
	"talon_dmr": "GunMetalKnurled",
}


func _materials(id: String) -> Dictionary[String, Material]:
	var gun: Node3D = (load("res://assets/models/weapons/%s.glb" % id) as PackedScene).instantiate() as Node3D
	var out: Dictionary[String, Material] = {}
	for node: Node in gun.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var material: Material = mesh.surface_get_material(i)
			out[material.resource_name] = material
	gun.free()
	return out


func test_every_gun_surface_uses_the_finish_shader() -> void:
	for id: String in GUNS:
		var materials: Dictionary[String, Material] = _materials(id)
		for mat_name: String in materials:
			var material: Material = materials[mat_name]
			if mat_name == "OpticGlass":
				assert_true(material is BaseMaterial3D, id + " optic glass keeps its standard material")
				continue
			assert_true(material is ShaderMaterial, "%s %s uses the finish shader" % [id, mat_name])
			if material is ShaderMaterial:
				assert_eq((material as ShaderMaterial).shader.resource_path, SHADER, "%s %s shader" % [id, mat_name])


func test_finish_follows_the_material_name() -> void:
	var shotgun: Dictionary[String, Material] = _materials("shotgun_brenner")
	assert_eq(_param(shotgun["Wood"], "finish"), 3, "walnut gets the wood grain")
	assert_eq(_param(shotgun["GunMetal"], "finish"), 0, "receiver is bare metal")
	assert_eq(_param(shotgun["MatteBlack"], "finish"), 1, "black parts are a coating")
	var talon: Dictionary[String, Material] = _materials("talon_dmr")
	assert_eq(_param(talon["GreyPolymer"], "finish"), 2, "grey stock is polymer")
	for id: String in KNURLED:
		var materials: Dictionary[String, Material] = _materials(id)
		assert_true(materials.has(KNURLED[id]), id + " has knurled parts")
		if materials.has(KNURLED[id]):
			assert_true(_param(materials[KNURLED[id]], "knurled"), id + " knurl pattern is on")
		assert_false(_param(materials["GunMetal"], "knurled"), id + " plain metal stays smooth")


func test_colour_metal_and_roughness_come_from_blender() -> void:
	var rifle: Dictionary[String, Material] = _materials("rifle_ar")
	var tan_color: Color = _param(rifle["Tan"], "albedo")
	assert_gt(tan_color.r, tan_color.b, "tan stays warm")
	assert_almost_eq(_param(rifle["GunMetal"], "metallic"), 0.8, 0.01, "gunmetal stays metallic")
	assert_almost_eq(_param(rifle["MatteBlack"], "roughness"), 0.75, 0.01, "black stays matte")


func test_unknown_material_keeps_its_standard_material() -> void:
	var source: StandardMaterial3D = StandardMaterial3D.new()
	source.resource_name = "Chrome"
	assert_eq(IMPORTER.finish_material(source), source, "an unmapped name is left alone")
	assert_push_error("has no finish")


func test_shader_multiplies_in_the_baked_shading() -> void:
	var code: String = (load(SHADER) as Shader).code
	assert_string_contains(code, "ALBEDO = color * ao")
	assert_string_contains(code, "float ao = COLOR.r")


func _param(material: Material, param: String) -> Variant:
	return (material as ShaderMaterial).get_shader_parameter(param)

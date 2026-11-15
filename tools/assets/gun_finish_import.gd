## Post-import script for the code-built guns: swaps each glTF material for the
## shared gun finish shader, keeping its colour, metal and roughness. The finish
## comes from the Blender material name; a "Knurled" suffix adds the knurl pattern.
## Optic glass keeps its standard material.
@tool
extends EditorScenePostImport

const SHADER: Shader = preload("res://assets/materials/gun_finish.gdshader")
const FINISHES: Dictionary[String, int] = {
	"GunMetal": 0,
	"MatteBlack": 1,
	"Tan": 2,
	"OlivePolymer": 2,
	"GreyPolymer": 2,
	"Wood": 3,
}
const KNURLED: String = "Knurled"
const STANDARD: Array[String] = ["OpticGlass"]


func _post_import(scene: Node) -> Object:
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var source: BaseMaterial3D = mesh.surface_get_material(i) as BaseMaterial3D
			if source == null:
				continue
			if source.resource_name in STANDARD:
				source.vertex_color_use_as_albedo = true
				continue
			mesh.surface_set_material(i, finish_material(source))
	return scene


static func finish_material(source: BaseMaterial3D) -> Material:
	var mat_name: String = source.resource_name
	var knurled: bool = mat_name.ends_with(KNURLED)
	var base: String = mat_name.trim_suffix(KNURLED)
	if not FINISHES.has(base):
		push_error("gun material '%s' has no finish; add it to FINISHES" % mat_name)
		return source
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = mat_name
	material.shader = SHADER
	material.set_shader_parameter(&"albedo", source.albedo_color)
	material.set_shader_parameter(&"metallic", source.metallic)
	material.set_shader_parameter(&"roughness", source.roughness)
	material.set_shader_parameter(&"finish", FINISHES[base])
	material.set_shader_parameter(&"knurled", knurled)
	return material

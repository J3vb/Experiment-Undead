## Replaces character and gear materials with the shared procedural finish,
## preserving the Blender colour and selecting the finish by material name.
@tool
extends EditorScenePostImport

const SHADER: Shader = preload("res://assets/materials/gear.gdshader")
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


func _post_import(scene: Node) -> Object:
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	if scene is MeshInstance3D:
		meshes.append(scene)
	for node: Node in meshes:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface: int in mesh.get_surface_count():
			var current: Material = mesh.surface_get_material(surface)
			if current is ShaderMaterial and (current as ShaderMaterial).shader == SHADER:
				continue
			mesh.surface_set_material(surface, finish_material(current as BaseMaterial3D))
	return scene


static func finish_material(source: BaseMaterial3D) -> ShaderMaterial:
	var mat_name: String = source.resource_name if source else ""
	if not FINISHES.has(mat_name):
		push_error("gear material '%s' has no finish; add it to FINISHES" % mat_name)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = mat_name
	material.shader = SHADER
	material.set_shader_parameter(&"albedo", source.albedo_color if source else Color.WHITE)
	material.set_shader_parameter(&"finish", FINISHES.get(mat_name, 0))
	return material

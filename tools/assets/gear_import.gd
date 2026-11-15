## Maps the four gear finishes to the shared alpha-zone dye and rarity shader.
@tool
extends EditorScenePostImport

const SHADER: Shader = preload("res://assets/materials/gear.gdshader")
const FINISHES: Dictionary[String, int] = {"GearFabric": 0, "GearWebbing": 1, "GearPlate": 2, "GearPolymer": 3}


func _post_import(scene: Node) -> Object:
	var materials: Dictionary[String, Material] = {}
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for index: int in mesh.get_surface_count():
			var source: BaseMaterial3D = mesh.surface_get_material(index) as BaseMaterial3D
			if source == null:
				continue
			var key: String = source.resource_name
			if not materials.has(key):
				materials[key] = finish_material(source)
			mesh.surface_set_material(index, materials[key])
	return scene


static func finish_material(source: BaseMaterial3D) -> Material:
	if not FINISHES.has(source.resource_name):
		push_error("gear material '%s' has no finish" % source.resource_name)
		return source
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = source.resource_name
	material.shader = SHADER
	material.set_shader_parameter(&"albedo", source.albedo_color)
	material.set_shader_parameter(&"metallic", source.metallic)
	material.set_shader_parameter(&"roughness", source.roughness)
	material.set_shader_parameter(&"finish", FINISHES[source.resource_name])
	return material

## Import script for Tripo zombies (tripo_intake.py --kind zombie): the Glower's one ZombieBaked material
## becomes a shared vein-glow ShaderMaterial (bio-green where its albedo is green). Other baked zombies keep
## the imported material.
@tool
extends EditorScenePostImport

const VEINS: Shader = preload("res://assets/materials/glower_veins.gdshader")
const BIO_GREEN: Color = Color("#8DFF3A")
const GLOWING: Array[String] = ["glower"]


func _post_import(scene: Node) -> Object:
	if get_source_file().get_file().get_basename() not in GLOWING:
		return scene
	var made: Dictionary[BaseMaterial3D, ShaderMaterial] = {}
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var source: BaseMaterial3D = mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				continue
			if not made.has(source):
				made[source] = vein_material(source)
			mesh.surface_set_material(surface, made[source])
	return scene


static func vein_material(source: BaseMaterial3D) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = source.resource_name
	material.shader = VEINS
	material.set_shader_parameter(&"albedo_tex", source.albedo_texture)
	material.set_shader_parameter(&"normal_tex", source.normal_texture)
	material.set_shader_parameter(&"orm_tex", source.roughness_texture)
	material.set_shader_parameter(&"glow_color", BIO_GREEN)
	return material

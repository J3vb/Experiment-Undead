## Zombie-only finish keeps source colours, main-zone AO and shared materials.
## The Belly instance dims the shared glow finish without adding a material slot.
@tool
extends EditorScenePostImport

const SHADER: Shader = preload("res://assets/materials/zombie_finish.gdshader")
const FINISHES: Dictionary[String, int] = {"ZombieSkin": 7, "ZombieCloth": 8, "ZombieShoe": 9, "ZombieGlow": 10}


func _post_import(scene: Node) -> Object:
	var materials: Dictionary[BaseMaterial3D, ShaderMaterial] = {}
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		instance.set_instance_shader_parameter(&"belly", instance.name == &"Belly")
		for surface: int in instance.mesh.get_surface_count():
			var current: Material = instance.mesh.surface_get_material(surface)
			if current is ShaderMaterial and (current as ShaderMaterial).shader == SHADER:
				continue
			var source: BaseMaterial3D = current as BaseMaterial3D
			if not materials.has(source):
				materials[source] = finish_material(source)
			instance.mesh.surface_set_material(surface, materials[source])
	return scene


static func finish_material(source: BaseMaterial3D) -> ShaderMaterial:
	var mat_name: String = source.resource_name if source else ""
	var finish: int = -1
	for prefix: String in FINISHES:
		if mat_name.begins_with(prefix):
			finish = FINISHES[prefix]
	if finish < 0:
		push_error("zombie material '%s' has no finish; add it to FINISHES" % mat_name)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = mat_name
	material.shader = SHADER
	material.set_shader_parameter(&"albedo", source.albedo_color if source else Color.WHITE)
	material.set_shader_parameter(&"roughness", source.roughness if source else 0.8)
	material.set_shader_parameter(&"finish", maxi(finish, 7))
	material.set_shader_parameter(&"pale_head", mat_name == "ZombieSkinHead")
	material.set_shader_parameter(&"decay", mat_name == "ZombieSkinDecay")
	if finish == 10:
		material.set_shader_parameter(&"emission_color", source.emission)
		material.set_shader_parameter(&"emission_strength", source.emission_energy_multiplier)
	return material

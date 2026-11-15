## Replaces character and gear materials with the shared procedural finish,
## preserving the Blender colour and selecting the finish by material name.
@tool
extends EditorScenePostImport

const SHADER: Shader = preload("res://assets/materials/gear.gdshader")
const GLASS_SHADER: Shader = preload("res://assets/materials/gear_glass.gdshader")
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
	"GearLiquid": 6,
	"ZombieSkin": 7,
	"ZombieCloth": 8,
	"ZombieShoe": 9,
	"ZombieGlow": 10,
}


func _post_import(scene: Node) -> Object:
	var materials: Dictionary[BaseMaterial3D, ShaderMaterial] = {}
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	if scene is MeshInstance3D:
		meshes.append(scene)
	for node: Node in meshes:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface: int in mesh.get_surface_count():
			var current: Material = mesh.surface_get_material(surface)
			if current is ShaderMaterial and (current as ShaderMaterial).shader in [SHADER, GLASS_SHADER]:
				continue
			var source: BaseMaterial3D = current as BaseMaterial3D
			if not materials.has(source):
				materials[source] = finish_material(source)
			mesh.surface_set_material(surface, materials[source])
	return scene


static func finish_material(source: BaseMaterial3D) -> ShaderMaterial:
	var mat_name: String = source.resource_name if source else ""
	var finish_name: String = mat_name
	for zombie_finish: String in ["ZombieSkin", "ZombieCloth", "ZombieShoe", "ZombieGlow"]:
		if mat_name.begins_with(zombie_finish):
			finish_name = zombie_finish
	if not FINISHES.has(finish_name) and finish_name != "GearGlass":
		push_error("gear material '%s' has no finish; add it to FINISHES" % mat_name)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = mat_name
	material.shader = GLASS_SHADER if finish_name == "GearGlass" else SHADER
	material.set_shader_parameter(&"albedo", source.albedo_color if source else Color.WHITE)
	if finish_name == "GearGlass":
		return material
	material.set_shader_parameter(&"finish", FINISHES.get(finish_name, 0))
	if finish_name == "ZombieGlow":
		material.set_shader_parameter(&"emission_color", source.emission)
		material.set_shader_parameter(&"emission_strength", source.emission_energy_multiplier)
	return material

## Replaces character and gear materials with the shared procedural finish,
## preserving the Blender colour and selecting the finish by material name.
## Materials that carry baked maps (the player body, ADR 0015) keep them.
@tool
extends EditorScenePostImport

const SHADER: Shader = preload("res://assets/materials/gear.gdshader")
const GLASS_SHADER: Shader = preload("res://assets/materials/gear_glass.gdshader")
const FINISHES: Dictionary[String, int] = {
	"BodySuit": 0,
	"BodyKnit": 5,
	"BodyRubber": 4,
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
## Player clips that cycle; glTF has no loop flag. Names match LOOPS in player_clips.py.
const LOOP_CLIPS: Array[StringName] = [
	&"idle",
	&"walk_fwd",
	&"walk_back",
	&"walk_left",
	&"walk_right",
	&"run",
	&"crouch_idle",
	&"crouch_walk",
	&"downed_idle",
	&"downed_crawl",
]
## Stall keeper clips that cycle. Names match LOOPS in npc_clips.py; `greet` plays once.
const KEEPER_LOOPS: Array[StringName] = [&"counter_idle", &"bench_work", &"desk_work", &"board_idle"]


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
			if source != null and source.albedo_texture != null:
				source.vertex_color_use_as_albedo = false  # vertex colour holds AO and paint zones, not colour
				continue
			if not materials.has(source):
				materials[source] = finish_material(source)
			mesh.surface_set_material(surface, materials[source])
	for node: Node in scene.find_children("*", "AnimationPlayer", true, false):
		_loop_clips(node as AnimationPlayer)
	return scene


static func _loop_clips(player: AnimationPlayer) -> void:
	for clip: StringName in player.get_animation_list():
		if clip in LOOP_CLIPS or clip in KEEPER_LOOPS:
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR


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

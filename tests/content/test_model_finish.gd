## Checks the finishing pass from tools/assets/finish.py survives import: finished
## models carry UVs and a baked AO/cavity vertex colour that their materials use,
## glowing parts stay unshaded, and the lightmapped wall panel is left alone.
extends GutTest

const FINISHED: Array[String] = [
	"weapons/rifle_ar",
	"weapons/kestrel_smg",
	"weapons/talon_dmr",
	"weapons/shotgun_brenner",
	"zombies/shambler",
	"zombies/crawler",
	"zombies/bloater",
]
const GLOWING: Dictionary[String, String] = {
	"weapons/rifle_ar": "OpticGlass",
	"zombies/shambler": "EyeL",
	"zombies/bloater": "Belly",
}
const GUN_SHADER: String = "res://assets/materials/gun_finish.gdshader"
const GEAR_SHADER: String = "res://assets/materials/gear.gdshader"
const WALL: String = "res://assets/models/kit/wall_panel.glb"


func _model(id: String) -> Node3D:
	var packed: PackedScene = load("res://assets/models/%s.glb" % id) as PackedScene
	assert_not_null(packed, id + " imports")
	return packed.instantiate() as Node3D if packed else null


## Procedural finishes multiply albedo by the baked vertex colour themselves.
func _uses_shading(material: Material) -> bool:
	if material is ShaderMaterial:
		return (material as ShaderMaterial).shader.resource_path in [GUN_SHADER, GEAR_SHADER]
	return (material as BaseMaterial3D).vertex_color_use_as_albedo


func _shades(model: Node3D) -> PackedFloat32Array:
	var values: PackedFloat32Array = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			assert_not_null(arrays[Mesh.ARRAY_COLOR], "%s has a shading colour" % node.name)
			assert_not_null(arrays[Mesh.ARRAY_TEX_UV], "%s has UVs" % node.name)
			assert_true(_uses_shading(mesh.surface_get_material(surface)), "%s material uses the shading" % node.name)
			if arrays[Mesh.ARRAY_COLOR] != null:
				for color: Color in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
					values.append(color.r)
	return values


func test_finished_models_carry_baked_shading() -> void:
	for id: String in FINISHED:
		var model: Node3D = _model(id)
		if model == null:
			continue
		var values: PackedFloat32Array = _shades(model)
		var darkest: float = 1.0
		var total: float = 0.0
		for value: float in values:
			darkest = minf(darkest, value)
			total += value
		assert_gt(darkest, 0.05, id + " shading never goes black")
		assert_lt(darkest, 0.7, id + " has occluded creases")
		assert_gt(total / values.size(), 0.5, id + " is mostly unshaded, not dimmed overall")
		model.free()


func test_glowing_parts_are_not_shaded() -> void:
	for id: String in GLOWING:
		var model: Node3D = _model(id)
		var glow: MeshInstance3D = model.find_child(GLOWING[id], true, false) as MeshInstance3D
		var colors: PackedColorArray = glow.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		for color: Color in colors:
			assert_almost_eq(color.r, 1.0, 0.01, "%s %s stays at full brightness" % [id, glow.name])
			break
		model.free()


func test_wall_panel_is_left_for_its_lightmap() -> void:
	var wall: Node3D = (load(WALL) as PackedScene).instantiate() as Node3D
	for node: Node in wall.find_children("*", "MeshInstance3D", true, false):
		var arrays: Array = (node as MeshInstance3D).mesh.surface_get_arrays(0)
		assert_null(arrays[Mesh.ARRAY_COLOR], "wall panel keeps the mesh its lightmap was baked on")
	wall.free()

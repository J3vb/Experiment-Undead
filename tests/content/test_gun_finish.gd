## Checks the gun finish from tools/assets/gun_finish_import.gd: every gun surface
## except optic glass uses the shared gun shader with the colour, finish and knurl
## its Blender material asked for, and the shader multiplies in the baked shading.
extends GutTest

const GUNS: Array[String] = [
	"rifle_ar",
	"kestrel_smg",
	"talon_dmr",
	"shotgun_brenner",
	"hollis_44",
	"mako_pdw",
	"atlas_auto",
	"halberd_lmg",
	"corvid_338",
	"siphon"
]
const SHADER: String = "res://assets/materials/gun_finish.gdshader"
const IMPORTER: GDScript = preload("res://tools/assets/gun_finish_import.gd")
const KNURLED: Dictionary[String, String] = {
	"rifle_ar": "GunMetalKnurled",
	"kestrel_smg": "MatteBlackKnurled",
	"talon_dmr": "GunMetalKnurled",
	"hollis_44": "WoodKnurled",
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


func test_rarity_overrides_are_local_to_each_mesh() -> void:
	var shared: ShaderMaterial = ShaderMaterial.new()
	shared.shader = load(SHADER) as Shader
	var common: MeshInstance3D = MeshInstance3D.new()
	var legendary: MeshInstance3D = MeshInstance3D.new()
	for part: MeshInstance3D in [common, legendary]:
		part.mesh = BoxMesh.new()
		part.material_override = shared
		add_child_autofree(part)
	common.set_instance_shader_parameter(&"rarity_color", Color("#D9D9D2"))
	legendary.set_instance_shader_parameter(&"rarity_color", Color("#FF8A1C"))
	assert_eq(common.get_instance_shader_parameter(&"rarity_color"), Color("#D9D9D2"))
	assert_eq(legendary.get_instance_shader_parameter(&"rarity_color"), Color("#FF8A1C"))
	assert_same(common.material_override, legendary.material_override, "rarity does not duplicate the finish")


func test_imported_rarity_masks_cover_only_a_thin_inlay() -> void:
	for id: String in GUNS:
		var gun: Node3D = (load("res://assets/models/weapons/%s.glb" % id) as PackedScene).instantiate() as Node3D
		var areas: Vector2 = Vector2.ZERO
		for node: Node in gun.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for surface: int in mesh.get_surface_count():
				areas += _inlay_area(mesh.surface_get_arrays(surface))
		assert_gt(areas.x, 0.0, id + " exports a rarity inlay")
		assert_lt(areas.x / areas.y, 0.02, id + " rarity stays below two percent of surface area")
		gun.free()


func test_optic_glass_stays_opaque_and_non_emissive() -> void:
	for id: String in ["rifle_ar", "talon_dmr", "corvid_338"]:
		var materials: Dictionary[String, Material] = _materials(id)
		var glass: BaseMaterial3D = materials["OpticGlass"] as BaseMaterial3D
		assert_false(glass.emission_enabled, id + " optic does not glow")
		assert_eq(glass.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, id + " optic keeps depth writing")


func test_existing_guns_leave_the_prototype_glow_zone_unused() -> void:
	for id: String in GUNS:
		var gun: Node3D = (load("res://assets/models/weapons/%s.glb" % id) as PackedScene).instantiate() as Node3D
		var glow_vertices: int = 0
		for node: Node in gun.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for surface: int in mesh.get_surface_count():
				var colors: PackedColorArray = mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				for color: Color in colors:
					if color.a > 0.15 and color.a < 0.5:
						glow_vertices += 1
		assert_eq(glow_vertices, 0, id + " keeps its existing inlay without emission")
		gun.free()


func _inlay_area(arrays: Array) -> Vector2:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var areas: Vector2 = Vector2.ZERO
	for index: int in range(0, indices.size(), 3):
		var a: int = indices[index]
		var b: int = indices[index + 1]
		var c: int = indices[index + 2]
		var area: float = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).length() * 0.5
		areas.y += area
		if colors[a].a < 0.5 or colors[b].a < 0.5 or colors[c].a < 0.5:
			areas.x += area
	return areas


func _param(material: Material, param: String) -> Variant:
	return (material as ShaderMaterial).get_shader_parameter(param)

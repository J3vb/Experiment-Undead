## Checks the shared Cold Containment look and the corridor look reference scene
## against the style-guide rules (AgX, volumetric fog, max 6 shadowed lights;
## see the look reference entry in docs/DECISIONS.md).
extends GutTest

const LOOK: String = "res://levels/looks/halcyon_interior.tres"
const CORRIDOR: String = "res://levels/look_reference/halcyon_corridor.tscn"
const MAX_SHADOWED_LIGHTS: int = 6


func test_interior_look_follows_the_style_guide() -> void:
	var env: Environment = load(LOOK) as Environment
	assert_not_null(env, "look loads as an Environment")
	if env == null:
		return
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_AGX, "AgX tonemapping")
	assert_true(env.volumetric_fog_enabled, "volumetric fog on")
	assert_true(env.glow_enabled, "glow on")
	assert_true(env.ssao_enabled, "SSAO on")
	assert_false(env.sdfgi_enabled, "SDFGI off (the corridor uses LightmapGI)")
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR, "flat ambient colour")


func test_corridor_uses_the_shared_look() -> void:
	var scene: Node = (load(CORRIDOR) as PackedScene).instantiate()
	add_child_autofree(scene)
	var world: WorldEnvironment = scene.find_child("WorldEnvironment", false, false) as WorldEnvironment
	assert_not_null(world, "corridor has a WorldEnvironment")
	if world:
		assert_not_null(world.environment, "environment is set")
	if world and world.environment:
		assert_eq(world.environment.resource_path, LOOK, "environment is the shared file, not a copy")
	assert_not_null(scene.find_child("Camera3D", false, false), "corridor has the reference camera")
	assert_not_null(scene.find_child("FilmPost", false, false), "corridor has film grain and vignette")


func test_corridor_keeps_the_shadow_light_budget() -> void:
	var scene: Node = (load(CORRIDOR) as PackedScene).instantiate()
	add_child_autofree(scene)
	var shadowed: int = 0
	for node: Node in scene.find_children("*", "Light3D", true, false):
		if (node as Light3D).shadow_enabled:
			shadowed += 1
	assert_gt(shadowed, 0, "some fixtures cast shadows")
	assert_lte(shadowed, MAX_SHADOWED_LIGHTS, "at most 6 shadowed lights")


func test_wall_panel_uses_the_grime_materials() -> void:
	var panel: Node = (load("res://assets/models/kit/wall_panel.glb") as PackedScene).instantiate()
	add_child_autofree(panel)
	var paths: Array[String] = []
	for mesh_node: Node in panel.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mesh_node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			paths.append(mesh.surface_get_material(i).resource_path)
	assert_has(paths, "res://levels/materials/panel_paint.tres", "panel paint is the grime shader")
	assert_has(paths, "res://levels/materials/panel_trim.tres", "panel trim is the grime shader")


func test_corridor_surfaces_have_procedural_detail() -> void:
	var scene: Node = (load(CORRIDOR) as PackedScene).instantiate()
	add_child_autofree(scene)
	var floor_mat: ShaderMaterial = (scene.find_child("Floor", true, false) as Block).material as ShaderMaterial
	assert_not_null(floor_mat, "floor is a shader material")
	if floor_mat:
		assert_eq(floor_mat.shader.resource_path, "res://levels/materials/wet_tiles.gdshader", "wet tiled floor")
		assert_not_null(floor_mat.get_shader_parameter("noise"), "floor has its puddle noise")
	var ceiling_mat: ShaderMaterial = (scene.find_child("Ceiling", true, false) as Block).material as ShaderMaterial
	assert_not_null(ceiling_mat, "ceiling is a shader material")
	if ceiling_mat:
		var noise: Texture2D = ceiling_mat.get_shader_parameter("noise") as Texture2D
		if noise == null:
			noise = ceiling_mat.shader.get_default_texture_parameter("noise")
		assert_not_null(noise, "ceiling has its stain noise")
		assert_same(noise, load("res://levels/materials/grime_noise.tres"), "ceiling uses the shared stain noise")


func test_every_fixture_has_a_housing_and_the_rim_light_is_cheap() -> void:
	var scene: Node = (load(CORRIDOR) as PackedScene).instantiate()
	add_child_autofree(scene)
	var lights: Node = scene.find_child("Lights", false, false)
	var fixtures: int = lights.find_children("Fixture*", "SpotLight3D", false, false).size()
	var housings: int = lights.find_children("Housing*", "MeshInstance3D", false, false).size()
	assert_gt(fixtures, 0, "corridor has fixtures")
	assert_eq(housings, fixtures, "one housing per fixture")
	var rim: SpotLight3D = lights.find_child("ZombieRim", false, false) as SpotLight3D
	assert_not_null(rim, "rim light keeps zombies readable")
	if rim:
		assert_false(rim.shadow_enabled, "rim light casts no shadow (budget)")
		assert_gt(-rim.global_basis.z.z, 0.0, "rim light shines back toward the camera (+Z)")


func test_corridor_has_baked_lightmaps_and_no_spill_lights() -> void:
	var scene: Node = (load(CORRIDOR) as PackedScene).instantiate()
	add_child_autofree(scene)
	var lightmap: LightmapGI = scene.find_child("LightmapGI", false, false) as LightmapGI
	assert_not_null(lightmap, "corridor has a LightmapGI")
	if lightmap:
		assert_not_null(lightmap.light_data, "lightmaps are baked")
	assert_eq(scene.find_children("Spill*", "Light3D", true, false).size(), 0, "bounce comes from the bake")


func test_corridor_light_bake_modes() -> void:
	var scene: Node = (load(CORRIDOR) as PackedScene).instantiate()
	add_child_autofree(scene)
	var real_time: Array[Node] = scene.find_children("Fixture*", "Light3D", true, false)
	real_time.append(scene.find_child("Glow", true, false))
	for light: Node in real_time:
		assert_eq((light as Light3D).light_bake_mode, Light3D.BAKE_DYNAMIC, "%s bakes its bounce" % light.name)
	for cheat: String in ["ZombieRim", "ViewFill"]:
		var light: Light3D = scene.find_child(cheat, true, false) as Light3D
		assert_eq(light.light_bake_mode, Light3D.BAKE_DISABLED, "%s stays out of the bake" % cheat)


func test_zombies_and_rifle_are_not_baked() -> void:
	var scene: Node = (load(CORRIDOR) as PackedScene).instantiate()
	add_child_autofree(scene)
	for root: String in ["Zombies", "Camera3D"]:
		var meshes: Array[Node] = scene.find_child(root, false, false).find_children("*", "MeshInstance3D", true, false)
		assert_gt(meshes.size(), 0, "%s has meshes" % root)
		for mesh: Node in meshes:
			var gi_mode: int = (mesh as MeshInstance3D).gi_mode
			assert_eq(gi_mode, GeometryInstance3D.GI_MODE_DYNAMIC, "%s lit by probes" % mesh.name)


func test_each_fixture_glows_onto_the_ceiling_in_the_bake_only() -> void:
	var scene: Node = (load(CORRIDOR) as PackedScene).instantiate()
	add_child_autofree(scene)
	var lights: Node = scene.find_child("Lights", false, false)
	var fixtures: Array[Node] = lights.find_children("Fixture*", "SpotLight3D", false, false)
	var glows: Array[Node] = lights.find_children("CeilingGlow*", "OmniLight3D", false, false)
	assert_eq(glows.size(), fixtures.size(), "one ceiling glow per fixture")
	for node: Node in glows:
		var glow: OmniLight3D = node as OmniLight3D
		assert_eq(glow.light_bake_mode, Light3D.BAKE_STATIC, "%s is baked, no run-time cost" % glow.name)
		assert_false(glow.shadow_enabled, "%s casts no shadow" % glow.name)
		assert_eq(glow.light_volumetric_fog_energy, 0.0, "%s adds no fog glow" % glow.name)
	for i: int in mini(glows.size(), fixtures.size()):
		var fixture: Vector3 = (fixtures[i] as Node3D).global_position
		var offset: Vector3 = (glows[i] as Node3D).global_position - fixture
		assert_lt(offset.length(), 0.3, "%s sits at its fixture" % glows[i].name)

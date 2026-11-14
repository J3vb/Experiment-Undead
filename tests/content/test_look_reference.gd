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
	assert_false(env.sdfgi_enabled, "SDFGI off (LightmapGI later)")
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

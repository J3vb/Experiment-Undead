## The booth keeps its warm, readable light profile and an extensible model list.
extends GutTest

const BOOTH: PackedScene = preload("res://tools/gear_booth.tscn")
const SCRIPT: Script = preload("res://tools/gear_booth.gd")


func test_booth_has_agx_neutral_floor_key_rim_and_orbit_camera() -> void:
	var booth: Node3D = BOOTH.instantiate() as Node3D
	autofree(booth)
	var world: WorldEnvironment = booth.get_node("WorldEnvironment") as WorldEnvironment
	assert_eq(world.environment.tonemap_mode, Environment.TONE_MAPPER_AGX)
	var lights: Array[Node] = booth.find_children("*", "Light3D", true, false)
	assert_eq(lights.size(), 2, "one key and one rim")
	var key: Light3D = booth.get_node("Key") as Light3D
	assert_true(key.shadow_enabled, "key anchors the model to the floor")
	assert_gt(key.light_color.r, key.light_color.b, "town key is warm sodium")
	var floor_mesh: MeshInstance3D = booth.get_node("Floor") as MeshInstance3D
	var material: StandardMaterial3D = floor_mesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert_eq(material.albedo_color.r, material.albedo_color.g, "floor is neutral grey")
	assert_eq(material.albedo_color.g, material.albedo_color.b)
	assert_not_null(booth.get_node("Turntable/Camera3D"), "camera orbits a fixed model")


func test_booth_model_list_and_rarity_rows_load() -> void:
	assert_eq(SCRIPT.SIZE, Vector2i(1280, 720))
	assert_eq(SCRIPT.VIEWS.keys(), ["front", "three_quarter", "side", "back"])
	assert_has(SCRIPT.MODELS, "res://assets/models/characters/player.glb")
	for path: String in SCRIPT.MODELS:
		assert_not_null(load(path) as PackedScene, "booth model loads: " + path)
	for rarity: String in SCRIPT.RARITIES:
		assert_not_null(load("res://content/looks/rarity/%s.tres" % rarity) as RarityLook)

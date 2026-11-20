## The match-start warm-up draws the very meshes the first kill, headshot and loot drop use (so their
## shaders compile before the fight), hidden in front of the camera, then frees itself.
extends GutTest

const LOOT: PackedScene = preload("res://systems/loot/loot_drop.tscn")


func test_warm_up_covers_the_meshes_effects_draw() -> void:
	var meshes: Array[Mesh] = ShaderWarmUp.meshes()
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var impact: Impact = Impact.spawn(parent, Vector3.ZERO, Vector3.UP, Impact.Kind.FLESH)
	assert_has(meshes, impact._flesh.mesh, "blood burst")
	assert_has(meshes, impact._mark.mesh, "bullet mark")
	var pop: HeadPop = HeadPop.spawn(parent, Vector3.ZERO)
	assert_has(meshes, pop._mist.mesh, "head pop mist")
	assert_has(meshes, (pop.chunks[0].get_child(1) as MeshInstance3D).mesh, "head pop chunk")
	assert_has(meshes, BloodPool._shared_mesh(), "blood pool")


func test_loot_drops_share_the_warmed_glow_shader() -> void:
	var a: LootDrop = _drop("rare")
	var b: LootDrop = _drop("rare")
	var ring_a: StandardMaterial3D = (a.get_node("Ring") as MeshInstance3D).material_override
	var ring_b: StandardMaterial3D = (b.get_node("Ring") as MeshInstance3D).material_override
	assert_same(ring_a, ring_b, "one material per rarity, not one per drop")
	var warm: StandardMaterial3D = LootDrop.warm_up_meshes()[0].surface_get_material(0)
	for feature: String in ["emission_enabled", "shading_mode", "transparency", "albedo_texture"]:
		assert_eq(warm.get(feature), ring_a.get(feature), "same %s, so the same shader" % feature)


func test_particle_materials_draw_as_particles() -> void:
	var warm: ShaderWarmUp = ShaderWarmUp.new()
	add_child_autofree(warm)
	var particles: int = 0
	var plain: int = 0
	for child: Node in warm.get_children():
		particles += int(child is CPUParticles3D)
		plain += int(child is MeshInstance3D)
	assert_eq(particles + plain, ShaderWarmUp.meshes().size(), "one drawer per mesh")
	assert_gt(particles, 0, "blood and mist are particles")
	assert_gt(plain, 0, "marks and chunks are meshes")


func test_draws_in_front_of_the_camera_then_frees_itself() -> void:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	camera.make_current()
	camera.position = Vector3(3, 1.7, 2)
	var warm: ShaderWarmUp = ShaderWarmUp.new()
	add_child(warm)
	await wait_process_frames(2)
	assert_true(warm.visible)
	assert_almost_eq(warm.global_position, camera.global_transform * ShaderWarmUp.SPOT, Vector3.ONE * 0.01)
	assert_lt(warm.global_position.y, 0.0, "below the floor the camera stands on")
	await wait_process_frames(ShaderWarmUp.FRAMES + 2)
	assert_false(is_instance_valid(warm), "gone after its frames")


func _drop(rarity: String) -> LootDrop:
	var drop: LootDrop = LOOT.instantiate() as LootDrop
	drop.item = {"uid": rarity, "base": "vest_light", "rar": rarity, "ilvl": 1}
	add_child_autofree(drop)
	return drop

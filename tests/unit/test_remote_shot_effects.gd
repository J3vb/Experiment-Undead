## A remote player's tracers reuse one node and one mesh, and hide after a short flash.
extends GutTest

const RIFLE: String = "res://content/weapons/rifle_ar.tres"


func _shoot(effects: RemoteShotEffects) -> void:
	effects.play(load(RIFLE) as WeaponData, Vector3.ZERO, PackedVector3Array([Vector3.FORWARD * 10.0]))


func test_shots_redraw_one_tracer_node_and_hide_it_after_the_flash() -> void:
	var effects: RemoteShotEffects = RemoteShotEffects.new()
	add_child_autofree(effects)
	_shoot(effects)
	var tracers: MeshInstance3D = effects.get_node("Tracers") as MeshInstance3D
	var mesh: Mesh = tracers.mesh
	_shoot(effects)
	assert_eq(effects.find_children("Tracers*", "MeshInstance3D", false, false).size(), 1)
	assert_same(effects.get_node("Tracers"), tracers)
	assert_same(tracers.mesh, mesh)
	assert_eq(mesh.get_surface_count(), 1, "the second shot replaces the first shot's lines")
	assert_true(tracers.visible)
	effects._process(RemoteShotEffects.TRACER_TIME + 0.01)
	assert_false(tracers.visible)


func test_tracer_material_is_shared_between_players() -> void:
	var a: RemoteShotEffects = RemoteShotEffects.new()
	var b: RemoteShotEffects = RemoteShotEffects.new()
	add_child_autofree(a)
	add_child_autofree(b)
	_shoot(a)
	_shoot(b)
	var mesh_a: Mesh = (a.get_node("Tracers") as MeshInstance3D).mesh
	var mesh_b: Mesh = (b.get_node("Tracers") as MeshInstance3D).mesh
	assert_same(mesh_a.surface_get_material(0), mesh_b.surface_get_material(0))

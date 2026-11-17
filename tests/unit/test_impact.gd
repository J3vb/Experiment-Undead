## Impacts reuse the oldest of at most 48 nodes and share their meshes and materials.
extends GutTest

var _parent: Node3D


func before_each() -> void:
	Impact._ring.clear()
	Impact._next = 0
	_parent = Node3D.new()
	add_child_autofree(_parent)


func _impacts(parent: Node) -> int:
	var count: int = 0
	for child: Node in parent.get_children():
		if child is Impact:
			count += 1
	return count


func test_sixty_spawns_keep_at_most_forty_eight_nodes() -> void:
	var first: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	for index: int in 59:
		Impact.spawn(_parent, Vector3(index, 0, 0), Vector3.UP, Impact.Kind.SURFACE)
	assert_eq(_impacts(_parent), Impact.MAX_ALIVE)
	assert_false(first.is_queued_for_deletion())


func test_spawn_after_the_cap_reuses_the_oldest_at_the_new_point() -> void:
	var first: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.FLESH)
	for index: int in Impact.MAX_ALIVE - 1:
		Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.FLESH)
	var reused: Impact = Impact.spawn(_parent, Vector3(5, 0, 0), Vector3.UP, Impact.Kind.SURFACE)
	assert_same(reused, first)
	assert_almost_eq(reused.global_position, Vector3(5, 0.01, 0), Vector3.ONE * 0.001)
	assert_true(reused._surface.visible and reused._surface.emitting)
	assert_false(reused._flesh.visible)
	assert_true(reused._mark.visible)


func test_impacts_of_a_kind_share_mesh_and_material() -> void:
	var a: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	var b: Impact = Impact.spawn(_parent, Vector3.ONE, Vector3.UP, Impact.Kind.SURFACE)
	assert_same(a._surface.mesh, b._surface.mesh)
	assert_same((a._surface.mesh as QuadMesh).material, (b._surface.mesh as QuadMesh).material)
	assert_same(a._mark.mesh, b._mark.mesh)
	assert_same(a._flesh.mesh, b._flesh.mesh)


func test_impact_hides_after_its_lifetime() -> void:
	var impact: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.FLESH)
	assert_true(impact.visible)
	impact._process(Impact.FLESH_LIFETIME + 0.01)
	assert_false(impact.visible)
	assert_false(impact.is_processing())


func test_freed_parent_does_not_break_the_ring() -> void:
	var old_parent: Node3D = Node3D.new()
	add_child(old_parent)
	for index: int in Impact.MAX_ALIVE:
		Impact.spawn(old_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	old_parent.free()
	var impact: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	assert_true(is_instance_valid(impact))
	assert_same(impact.get_parent(), _parent)


func test_impact_under_another_parent_moves_to_the_new_one() -> void:
	var other: Node3D = Node3D.new()
	add_child_autofree(other)
	var first: Impact = Impact.spawn(other, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	for index: int in Impact.MAX_ALIVE - 1:
		Impact.spawn(other, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	assert_same(Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE), first)
	assert_same(first.get_parent(), _parent)

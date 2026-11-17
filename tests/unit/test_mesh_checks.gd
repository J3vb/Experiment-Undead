## The shared model-check helper finds meshes on a line, through nested transforms.
extends GutTest

var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	var holder: Node3D = Node3D.new()
	holder.position = Vector3(0, 1, 0)
	_root.add_child(holder)
	var box: MeshInstance3D = MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.position = Vector3(0, 0, -2)
	holder.add_child(box)
	add_child_autofree(_root)


func test_segment_through_a_nested_box_is_blocked() -> void:
	assert_true(MeshChecks.blocks_segment(_root, Vector3(0, 1, 0), Vector3(0, 1, -4)))


func test_segment_that_stops_short_is_open() -> void:
	assert_false(MeshChecks.blocks_segment(_root, Vector3(0, 1, 0), Vector3(0, 1, -1)))


func test_ray_follows_its_direction() -> void:
	assert_true(MeshChecks.blocks_ray(_root, Vector3(0, 1, 0), Vector3.FORWARD))
	assert_false(MeshChecks.blocks_ray(_root, Vector3(0, 1, 0), Vector3.BACK))
	assert_false(MeshChecks.blocks_ray(_root, Vector3(0, 0, 0), Vector3.FORWARD), "the holder lifts the box")

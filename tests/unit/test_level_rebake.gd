## A door rebake bakes the navmesh on a worker thread (no main-thread freeze), and requests made while a
## bake runs give one more bake afterwards, so the last door bought is always in the navmesh.
extends GutTest

var _level: Level


func before_each() -> void:
	_level = Level.new()
	var region: NavigationRegion3D = NavigationRegion3D.new()
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Layers.WORLD
	region.navigation_mesh = mesh
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20, 0.5, 20)
	shape.shape = box
	floor_body.add_child(shape)
	region.add_child(floor_body)
	_level.add_child(region)
	_level.navigation_region = region
	add_child_autofree(_level)


func test_rebake_runs_on_a_worker_thread() -> void:
	_level.rebake_navigation()
	_level.rebake_navigation()
	assert_true(_level.is_rebaking(), "one rebake queued for the end of the frame")
	await wait_until(func() -> bool: return not _level.is_rebaking(), 10.0, "rebake finished")
	assert_false(_level.navigation_region.is_baking())
	assert_gt(_level.navigation_region.navigation_mesh.get_polygon_count(), 0, "the floor is baked")


func test_a_request_during_a_bake_bakes_again_after_it() -> void:
	var bakes: Array[int] = [0]
	_level.navigation_region.bake_finished.connect(func() -> void: bakes[0] += 1)
	_level.navigation_region.bake_navigation_mesh(true)
	assert_true(_level.navigation_region.is_baking(), "a bake runs in the background")
	_level.rebake_navigation()
	_level._rebake_now()
	assert_true(_level.is_rebaking(), "the request waits for the running bake")
	await wait_until(func() -> bool: return not _level.is_rebaking(), 10.0, "both bakes finished")
	await wait_process_frames(2)
	assert_eq(bakes[0], 2, "two bakes, one after the other")

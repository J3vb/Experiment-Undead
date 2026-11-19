## Every solid-looking model a player can walk into is backed by a world collider, so nothing in a map
## is a ghost the player passes through. A model players may pass on purpose (soft snow, things outside
## the walls) carries metadata/walk_through = "<reason>" on itself or a parent node.
extends GutTest

const LEVELS: Array[String] = ["res://levels/halcyon_labs/map.tscn", "res://levels/lantern_post/lantern_post.tscn"]
## Lower than this above the floor you step over or wade through it (spills, body bags, rugs).
const LOW: float = 0.5
## A model this high above the floor hangs over the player's head (1.8 m capsule).
const OVERHEAD: float = 1.9
## Thinner than this it is flat on a wall or the floor.
const THIN: float = 0.1
## The probe box is this part of the model's footprint, so the collider sits where the model is.
const CORE: float = 0.5


func test_every_solid_model_has_a_collider() -> void:
	for path: String in LEVELS:
		var level: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		add_child_autofree(level)
		await wait_physics_frames(2)
		var ghosts: PackedStringArray = _ghosts(level)
		assert_eq(
			ghosts.size(),
			0,
			(
				(
					"%s: models with no collider, players walk through them. Add a collider, or set"
					+ " metadata/walk_through with the reason:\n%s"
				)
				% [path, "\n".join(ghosts)]
			)
		)


func test_walk_through_needs_a_reason() -> void:
	for path: String in LEVELS:
		var level: Node = (load(path) as PackedScene).instantiate()
		for node: Node in level.find_children("*", "", true, false):
			if node.has_meta(&"walk_through"):
				assert_gt(str(node.get_meta(&"walk_through")).length(), 5, "%s says why" % level.get_path_to(node))
		level.free()


func test_a_mesh_with_no_collider_is_found() -> void:
	var level: Node3D = Node3D.new()
	add_child_autofree(level)
	var crate: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	crate.mesh = mesh
	crate.position = Vector3(0, 0.5, 0)
	level.add_child(crate)
	await wait_physics_frames(2)
	assert_eq(_ghosts(level).size(), 1, "a lone crate is a ghost")
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	shape.shape = box
	body.add_child(shape)
	crate.add_child(body)
	await wait_physics_frames(2)
	assert_eq(_ghosts(level).size(), 0, "a crate with a box collider is solid")
	body.free()
	crate.set_meta(&"walk_through", "test crate")
	await wait_physics_frames(2)
	assert_eq(_ghosts(level).size(), 0, "walk_through skips it")


func _ghosts(level: Node3D) -> PackedStringArray:
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var probe: BoxShape3D = BoxShape3D.new()
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = Layers.WORLD
	var out: PackedStringArray = []
	for node: Node in level.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree() or _walk_through(mesh, level):
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if minf(box.size.x, box.size.z) < THIN:
			continue
		var floor_y: float = _floor_under(space, box)
		if box.end.y < floor_y + LOW or box.position.y > floor_y + OVERHEAD:
			continue
		var bottom: float = maxf(box.position.y, floor_y + 0.1)
		var top: float = minf(box.end.y, floor_y + OVERHEAD)
		probe.size = Vector3(box.size.x * CORE, top - bottom, box.size.z * CORE)
		query.transform = Transform3D(
			Basis.IDENTITY, Vector3(box.get_center().x, (bottom + top) * 0.5, box.get_center().z)
		)
		if space.intersect_shape(query, 1).is_empty():
			out.append("%s at %s" % [level.get_path_to(mesh), box.position.snapped(Vector3.ONE * 0.1)])
	return out


## The lowest world surface under the model's middle and corners (a ceiling lamp over a tall forklift
## still hangs over the floor), or the model's own bottom when there is none.
func _floor_under(space: PhysicsDirectSpaceState3D, box: AABB) -> float:
	var lowest: float = box.position.y
	var found: bool = false
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray.collision_mask = Layers.WORLD
	var y: float = box.position.y + 0.05
	for spot: Vector2 in [Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		ray.from = Vector3(box.position.x + box.size.x * spot.x, y, box.position.z + box.size.z * spot.y)
		ray.to = ray.from + Vector3.DOWN * 30.0
		var hit: Dictionary = space.intersect_ray(ray)
		if not hit.is_empty():
			var hit_y: float = (hit["position"] as Vector3).y
			lowest = hit_y if not found else minf(lowest, hit_y)
			found = true
	return lowest


func _walk_through(node: Node, level: Node) -> bool:
	while node != null and node != level.get_parent():
		if node.has_meta(&"walk_through"):
			return true
		node = node.get_parent()
	return false

## Checks the models built by tools/assets/build_models.py: they import,
## have the right size and axes, and keep the parts code needs by name.
extends GutTest

const RIFLE: String = "res://assets/models/weapons/rifle_ar.glb"
const WALL: String = "res://assets/models/kit/wall_panel.glb"


func _bounds(node: Node, xform: Transform3D, out: Array[AABB]) -> void:
	var here: Transform3D = xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var box: AABB = here * (node as MeshInstance3D).get_aabb()
		out[0] = box if out[0].size == Vector3.ZERO else out[0].merge(box)
	for child: Node in node.get_children():
		_bounds(child, here, out)


func _size_of(scene: Node) -> AABB:
	var out: Array[AABB] = [AABB()]
	_bounds(scene, Transform3D.IDENTITY, out)
	return out[0]


func _load(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, path + " imports as a scene")
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func test_rifle_has_moving_parts_and_muzzle() -> void:
	var gun: Node3D = _load(RIFLE)
	if gun == null:
		return
	for part: String in ["Magazine", "Bolt", "Muzzle", "Barrel", "OpticGlass"]:
		assert_not_null(gun.find_child(part, true, false), "rifle has " + part)
	var muzzle: Node3D = gun.find_child("Muzzle", true, false) as Node3D
	if muzzle:
		assert_lt(muzzle.position.z, -0.5, "muzzle points forward (-Z)")
	var box: AABB = _size_of(gun)
	assert_almost_eq(box.size.z, 1.02, 0.03, "rifle is about 1 m long")
	assert_lt(box.size.x, 0.1, "rifle is narrow")
	gun.free()


func test_rifle_body_is_one_mesh() -> void:
	var gun: Node3D = _load(RIFLE)
	if gun == null:
		return
	var receiver: Node = gun.find_child("Receiver", true, false)
	assert_true(receiver is MeshInstance3D, "static rifle parts are joined into Receiver")
	var meshes: Array[Node] = gun.find_children("*", "MeshInstance3D", true, false)
	assert_lt(meshes.size(), 10, "few draw calls: only moving parts are separate meshes")
	gun.free()


func test_wall_panel_fits_the_kit_grid() -> void:
	var wall: Node3D = _load(WALL)
	if wall == null:
		return
	var box: AABB = _size_of(wall)
	assert_almost_eq(box.size.x, 2.0, 0.01, "wall is 2 m wide")
	assert_almost_eq(box.size.y, 3.0, 0.01, "wall is 3 m high")
	assert_almost_eq(box.position.y, 0.0, 0.01, "origin at the floor")
	assert_lt(box.size.z, 0.3, "wall is thin")
	wall.free()

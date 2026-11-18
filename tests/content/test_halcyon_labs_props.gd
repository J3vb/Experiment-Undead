## Checks the Halcyon Labs prop models and dressing (plan F-15): model props keep a
## plain box collider of their layout box and fit inside it, dressing never collides
## and stays clear of doors, machines and spawns, and the map stays under its prop caps.
## Each main room has one ceiling model (plan F-68 step 6) above head height.
extends GutTest

const MAP: String = "res://levels/halcyon_labs/map.tscn"
const BUILDER: String = "res://tools/blockout_builder.gd"
const MAX_MODEL_PROPS: int = 60
const MAX_DRESSING: int = 80
## Dressing keeps this far (m) from openings, interactables and spawn points.
const DRESSING_CLEARANCE: float = 1.0
## A model may poke this far (m) out of its box (bevels, rounding).
const BOX_SLACK: float = 0.05
## Dressing whose lowest point is this high (m) above its floor cannot block or hide anything.
const HEAD_HEIGHT: float = 2.2
const CEILING_ROOMS: Array[String] = [
	"loading_dock",
	"guard_post",
	"mess_hall",
	"main_corridor",
	"generator_hall",
	"labs",
	"coolant_tunnel",
	"containment_wing",
]

var _layout: Dictionary
var _built: Node3D


func before_all() -> void:
	var builder: GDScript = load(BUILDER) as GDScript
	_layout = builder.load_layout("halcyon_labs")
	_built = builder.build(_layout)


func after_all() -> void:
	_built.free()


func _model_props() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in _layout["props"]:
		if prop.has("model"):
			out.append(prop)
	return out


func _prop_node(prop: Dictionary) -> Node3D:
	return _built.get_node(NodePath("%s/Props/%s" % [prop["room"], prop["id"]])) as Node3D


func test_prop_and_dressing_counts_stay_under_the_caps() -> void:
	assert_gt(_model_props().size(), 0, "some props use models")
	assert_lte(_model_props().size(), MAX_MODEL_PROPS, "model props cap")
	assert_lte((_layout.get("dressing", []) as Array).size(), MAX_DRESSING, "dressing cap")


func test_no_prop_is_a_grey_box() -> void:
	for prop: Dictionary in _layout["props"]:
		assert_true(prop.has("model"), "%s in %s uses a model" % [prop["id"], prop["room"]])


func test_model_props_collide_as_their_box_without_a_grey_block() -> void:
	for prop: Dictionary in _model_props():
		var node: Node3D = _prop_node(prop)
		assert_false(node is Block, "%s is not a grey Block" % prop["id"])
		assert_true(node is StaticBody3D, "%s is a static body" % prop["id"])
		assert_eq((node as StaticBody3D).collision_layer, Layers.WORLD, "%s is world geometry" % prop["id"])
		var shapes: Array[Node] = node.find_children("*", "CollisionShape3D", true, false)
		assert_eq(shapes.size(), 1, "%s has one collider" % prop["id"])
		var b: Array = prop["box"]
		var box: BoxShape3D = (shapes[0] as CollisionShape3D).shape as BoxShape3D
		assert_not_null(box, "%s collider is a box" % prop["id"])
		if box:
			assert_eq(box.size, Vector3(b[3], b[4], b[5]), "%s collider is its layout box" % prop["id"])
		assert_not_null(node.get_node_or_null(^"Model"), "%s shows its model" % prop["id"])


func test_model_props_fit_inside_their_box() -> void:
	for prop: Dictionary in _model_props():
		var node: Node3D = _prop_node(prop)
		var b: Array = prop["box"]
		var half: Vector3 = Vector3(b[3], b[4], b[5]) * 0.5 + Vector3.ONE * BOX_SLACK
		var bounds: AABB = _bounds(node.get_node(^"Model") as Node3D, node)
		var fits: bool = AABB(-half, half * 2.0).encloses(bounds)
		assert_true(fits, "%s model %s fits in its box %s" % [prop["id"], bounds, half * 2.0])


## Bounds of every mesh under `model`, in the space of `space`.
func _bounds(model: Node3D, space: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var to_space: Transform3D = _relative(mesh, space)
		var box: AABB = to_space * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _relative(node: Node3D, space: Node3D) -> Transform3D:
	var xform: Transform3D = Transform3D.IDENTITY
	var at: Node = node
	while at != space:
		xform = (at as Node3D).transform * xform
		at = at.get_parent()
	return xform


func test_dressing_never_collides_and_sits_in_its_room() -> void:
	var rooms: Dictionary = {}
	for room: Dictionary in _layout["rooms"]:
		rooms[room["id"]] = room["rect"]
	for item: Dictionary in _layout.get("dressing", []):
		var node: Node = _built.get_node(NodePath("%s/Dressing/%s" % [item["room"], item["id"]]))
		assert_eq(
			node.find_children("*", "CollisionObject3D", true, false).size(), 0, "%s has no collider" % item["id"]
		)
		var r: Array = rooms[item["room"]]
		var inside: Rect2 = Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).grow(-0.2)
		assert_true(
			inside.has_point(Vector2(item["at"][0], item["at"][2])), "%s sits in %s" % [item["id"], item["room"]]
		)


func test_dressing_stays_clear_of_doors_machines_and_spawns() -> void:
	var keep_clear: Array[Vector3] = []
	for opening: Dictionary in _layout["openings"]:
		keep_clear.append(Vector3(opening["at"][0], opening["at"][1], float(opening["width"]) * 0.5))
	var level: Level = (load(MAP) as PackedScene).instantiate() as Level
	add_child_autofree(level)
	for node: Node in level.find_children("*", "Node3D"):
		if node is Interactable or node is ZombieSpawnPoint or node.is_in_group(&"vault_spot"):
			var at: Vector3 = (node as Node3D).global_position
			keep_clear.append(Vector3(at.x, at.z, 0.0))
	for item: Dictionary in _layout.get("dressing", []):
		var node: Node3D = _built.get_node(NodePath("%s/Dressing/%s" % [item["room"], item["id"]])) as Node3D
		var bounds: AABB = _bounds(node, node.get_parent() as Node3D)
		if bounds.position.y >= HEAD_HEIGHT:
			continue
		var room: Node3D = node.get_parent().get_parent() as Node3D
		var footprint: Rect2 = Rect2(
			bounds.position.x + room.position.x, bounds.position.z + room.position.z, bounds.size.x, bounds.size.z
		)
		for point: Vector3 in keep_clear:
			var nearest: Vector2 = Vector2(point.x, point.y).clamp(footprint.position, footprint.end)
			var gap: float = nearest.distance_to(Vector2(point.x, point.y)) - point.z
			assert_gte(gap, DRESSING_CLEARANCE, "%s is clear of %s" % [item["id"], Vector2(point.x, point.y)])


func test_each_main_room_has_one_ceiling_model_above_head_height() -> void:
	var heights: Dictionary = {}
	for room: Dictionary in _layout["rooms"]:
		heights[room["id"]] = float(room["height"])
	var found: Dictionary = {}
	for item: Dictionary in _layout.get("dressing", []):
		if not String(item["model"]).begins_with("ceiling_"):
			continue
		found[item["room"]] = int(found.get(item["room"], 0)) + 1
		var node: Node3D = _built.get_node(NodePath("%s/Dressing/%s" % [item["room"], item["id"]])) as Node3D
		var bounds: AABB = _bounds(node, node.get_parent() as Node3D)
		assert_gte(bounds.position.y, HEAD_HEIGHT, "%s hangs above head height" % item["id"])
		assert_lte(bounds.end.y, float(heights[item["room"]]), "%s stays under the ceiling" % item["id"])
	for room_id: String in CEILING_ROOMS:
		assert_eq(int(found.get(room_id, 0)), 1, "%s has one ceiling model" % room_id)

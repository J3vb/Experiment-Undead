## Turns levels/<map>/layout.json into levels/<map>/blockout.tscn: floors,
## ceilings, panelled walls with door and window cuts, ramps, ceiling lights and
## props (boxes or Blender models with a box collider) under each room's Props
## node, and visual-only dressing models under its Dressing node.
## Rooms with "lights": false (the small spaces behind windows) get no lights.
## "light_states" marks lights (by index) that flicker, or are dead: a dark
## housing with no light at all, so the lightmap bake gets nothing from it.
## Never hand-edit the output; change the JSON and run this again:
##   godot --headless --path . -s res://tools/blockout_builder.gd -- halcyon_labs
extends SceneTree

const WALL_PANEL: String = "res://assets/models/kit/wall_panel.glb"
const CEILING_LIGHT: String = "res://levels/kit/ceiling_light.tscn"
const DEAD_LIGHT: String = "res://levels/kit/ceiling_light_dead.tscn"
const MATERIALS: String = "res://levels/materials/%s.tres"
const PROP_MODEL: String = "res://assets/models/props/%s.glb"
const DRESSING_MODEL: String = "res://assets/models/dressing/%s.glb"
const WALL_THICKNESS: float = 0.2
const PANEL_WIDTH: float = 2.0
const PANEL_HEIGHT: float = 3.0
const DOOR_HEIGHT: float = 2.6
const LIGHT_SPACING: float = 6.0
const LIGHT_HANG: float = 3.5
const SHADOWED_LIGHTS_PER_ROOM: int = 2


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var map_id: String = args[0] if not args.is_empty() else "halcyon_labs"
	var root: Node3D = build(load_layout(map_id))
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	var out: String = "res://levels/%s/blockout.tscn" % map_id
	var err: Error = ResourceSaver.save(packed, out)
	print("saved %s (%s)" % [out, error_string(err)])
	root.free()
	quit(0 if err == OK else 1)


static func load_layout(map_id: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string("res://levels/%s/layout.json" % map_id)
	return JSON.parse_string(text) as Dictionary


static func build(layout: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Blockout"
	var openings: Array = _mark_ramp_ends(layout.get("openings", []), layout.get("ramps", []))
	var states: Dictionary = layout.get("light_states", {})
	for room: Dictionary in layout["rooms"]:
		_build_room(root, room, openings, states.get(room["id"], {}))
	var ramps: Node3D = _child(root, root, "Ramps")
	for i: int in (layout.get("ramps", []) as Array).size():
		_build_ramp(root, ramps, layout["ramps"][i], i)
	for prop: Dictionary in layout.get("props", []):
		_build_prop(root, prop)
	for item: Dictionary in layout.get("dressing", []):
		_build_dressing(root, item)
	return root


## box = [x, bottom above the room floor, z, size x, size y, size z] in map coordinates.
## With "model", the .glb from assets/models/props/ stands in the box (turned by
## "turn" degrees) and the box is only its collider, so collision and navmesh match a plain box.
static func _build_prop(root: Node3D, prop: Dictionary) -> void:
	var room: Node3D = root.get_node(NodePath(prop["room"])) as Node3D
	var props: Node3D = _group(root, room, "Props")
	var b: Array = prop["box"]
	var size: Vector3 = Vector3(b[3], b[4], b[5])
	var at: Vector3 = Vector3(b[0], room.position.y + float(b[1]) + size.y * 0.5, b[2]) - room.position
	if not prop.has("model"):
		_block(root, props, prop["id"], size, at, prop["material"])
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.name = prop["id"]
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = at
	props.add_child(body)
	body.owner = root
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	shape.owner = root
	var model: Node3D = _model(root, body, PROP_MODEL % prop["model"], float(prop.get("turn", 0.0)))
	model.position.y = -size.y * 0.5


## Visual-only models (signs, cables, clutter): no collider, never in the navmesh.
## at = [x, bottom above the room floor, z] in map coordinates.
static func _build_dressing(root: Node3D, item: Dictionary) -> void:
	var room: Node3D = root.get_node(NodePath(item["room"])) as Node3D
	var dressing: Node3D = _group(root, room, "Dressing")
	var a: Array = item["at"]
	var model: Node3D = _model(root, dressing, DRESSING_MODEL % item["model"], float(item.get("turn", 0.0)))
	model.name = item["id"]
	model.position = Vector3(a[0], room.position.y + float(a[1]), a[2]) - room.position


static func _model(root: Node3D, parent: Node3D, path: String, turn: float) -> Node3D:
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	model.rotation.y = deg_to_rad(turn)
	parent.add_child(model)
	model.owner = root
	return model


static func _group(root: Node3D, room: Node3D, label: String) -> Node3D:
	var node: Node3D = room.get_node_or_null(NodePath(label)) as Node3D
	return node if node != null else _child(root, room, label)


## An opening where a ramp ends gets no sill: the ramp fills the cut, and a
## sill top above the sloped ramp surface is a lip that stops zombies.
static func _mark_ramp_ends(openings: Array, ramps: Array) -> Array:
	var out: Array = []
	for opening: Dictionary in openings:
		var marked: Dictionary = opening.duplicate()
		var at: Vector3 = Vector3(opening["at"][0], float(opening["floor"]), opening["at"][1])
		for ramp: Dictionary in ramps:
			for end: Array in [ramp["from"], ramp["to"]]:
				if at.distance_to(Vector3(end[0], end[1], end[2])) < 0.01:
					marked["ramp_end"] = true
		out.append(marked)
	return out


static func _build_room(root: Node3D, room: Dictionary, openings: Array, light_state: Dictionary) -> void:
	var r: Array = room["rect"]
	var y: float = room["floor"]
	var h: float = room["height"]
	var size: Vector2 = Vector2(r[2] - r[0], r[3] - r[1])
	var centre: Vector3 = Vector3((r[0] + r[2]) * 0.5, y, (r[1] + r[3]) * 0.5)
	var node: Node3D = _child(root, root, room["id"])
	node.position = centre
	var floor_mat: String = room.get("floor_material", "tiled_wet_floor")
	_block(root, node, "Floor", Vector3(size.x, 0.5, size.y), Vector3(0, -0.25, 0), floor_mat)
	_block(root, node, "Ceiling", Vector3(size.x, 0.5, size.y), Vector3(0, h + 0.25, 0), "ceiling_stained")
	var walls: Node3D = _child(root, node, "Walls")
	# Each edge: start corner, inward normal, length, height. The wall runs along the rotated +X.
	var edges: Array[Array] = [
		[Vector3(r[0], y, r[1]), Vector3.BACK, size.x, h],
		[Vector3(r[2], y, r[3]), Vector3.FORWARD, size.x, h],
		[Vector3(r[0], y, r[3]), Vector3.RIGHT, size.y, h],
		[Vector3(r[2], y, r[1]), Vector3.LEFT, size.y, h],
	]
	for i: int in edges.size():
		_build_wall(root, walls, "Edge%d" % i, edges[i], openings, centre)
	if room.get("lights", true):
		_build_lights(root, node, size, minf(h, LIGHT_HANG) - 0.03, light_state)


static func _build_wall(
	root: Node3D, walls: Node3D, label: String, edge: Array, openings: Array, centre: Vector3
) -> void:
	var start: Vector3 = edge[0]
	var normal: Vector3 = edge[1]
	var length: float = edge[2]
	var h: float = edge[3]
	var basis: Basis = Basis(Vector3.UP, atan2(normal.x, normal.z))
	var along: Vector3 = basis.x
	var cuts: Array[Vector4] = _cuts(start, normal, length, openings)
	var wall_origin: Vector3 = start + normal * WALL_THICKNESS * 0.5 - centre
	var t0: float = 0.0
	var n: int = 0
	for cut: Vector4 in cuts:
		_wall_run(root, walls, "%sRun%d" % [label, n], Transform3D(basis, wall_origin + along * t0), cut.x - t0, h)
		var mid: Vector3 = wall_origin + along * (cut.x + cut.y) * 0.5
		var width: float = cut.y - cut.x
		if cut.z > 0.0 and cut.w == 0.0:
			_cut_piece(root, walls, "%sSill%d" % [label, n], Transform3D(basis, mid), Vector3(width, cut.z, 0))
		var top: float = cut.z + DOOR_HEIGHT
		_cut_piece(root, walls, "%sLintel%d" % [label, n], Transform3D(basis, mid), Vector3(width, h - top, top))
		t0 = cut.y
		n += 1
	_wall_run(root, walls, "%sRun%d" % [label, n], Transform3D(basis, wall_origin + along * t0), length - t0, h)


## Openings on this edge as (start t, end t, cut floor above the room floor, 1 if a ramp ends there),
## sorted along the wall.
static func _cuts(start: Vector3, normal: Vector3, length: float, openings: Array) -> Array[Vector4]:
	var along: Vector3 = Basis(Vector3.UP, atan2(normal.x, normal.z)).x
	var cuts: Array[Vector4] = []
	for opening: Dictionary in openings:
		var at: Vector3 = Vector3(opening["at"][0], start.y, opening["at"][1])
		var t: float = (at - start).dot(along)
		if absf((at - start).dot(normal)) < 0.01 and t > 0.0 and t < length:
			var half: float = float(opening["width"]) * 0.5
			var ramp_end: float = 1.0 if opening.get("ramp_end", false) else 0.0
			cuts.append(Vector4(t - half, t + half, float(opening["floor"]) - start.y, ramp_end))
	cuts.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.x < b.x)
	return cuts


## A solid stretch of wall: one collision box, kit panels in front, plain strip above them.
static func _wall_run(root: Node3D, walls: Node3D, label: String, at: Transform3D, length: float, h: float) -> void:
	if length < 0.05:
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.name = label
	body.collision_mask = 0
	body.transform = Transform3D(at.basis, at.origin + at.basis.x * length * 0.5)
	walls.add_child(body)
	body.owner = root
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(length, h, WALL_THICKNESS)
	shape.shape = box
	shape.position.y = h * 0.5
	body.add_child(shape)
	shape.owner = root
	var count: int = maxi(1, roundi(length / PANEL_WIDTH))
	var width: float = length / count
	var panel_scene: PackedScene = load(WALL_PANEL)
	for i: int in count:
		var panel: Node3D = panel_scene.instantiate() as Node3D
		panel.name = "Panel%d" % i
		panel.position = Vector3(-length * 0.5 + (i + 0.5) * width, 0, 0)
		panel.scale = Vector3(width / PANEL_WIDTH, minf(h, PANEL_HEIGHT) / PANEL_HEIGHT, 1)
		body.add_child(panel)
		panel.owner = root
	if h > PANEL_HEIGHT:
		var upper: MeshInstance3D = MeshInstance3D.new()
		upper.name = "Upper"
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(length, h - PANEL_HEIGHT, WALL_THICKNESS)
		mesh.add_uv2 = true
		mesh.material = load(MATERIALS % "panel_paint")
		upper.mesh = mesh
		upper.position.y = PANEL_HEIGHT + (h - PANEL_HEIGHT) * 0.5
		body.add_child(upper)
		upper.owner = root


## Wall above or below a door cut. size = (width, height, bottom).
static func _cut_piece(root: Node3D, walls: Node3D, label: String, at: Transform3D, size: Vector3) -> void:
	if size.y < 0.05:
		return
	var block: Block = _block(root, walls, label, Vector3(size.x, size.y, WALL_THICKNESS), Vector3.ZERO, "panel_paint")
	block.transform = Transform3D(at.basis, at.origin + Vector3(0, size.z + size.y * 0.5, 0))


static func _build_lights(root: Node3D, room: Node3D, size: Vector2, height: float, state: Dictionary) -> void:
	var lights: Node3D = _child(root, room, "Lights")
	var nx: int = maxi(1, roundi(size.x / LIGHT_SPACING))
	var nz: int = maxi(1, roundi(size.y / LIGHT_SPACING))
	var spots: Array[Vector3] = []
	for i: int in nx:
		for j: int in nz:
			spots.append(
				Vector3((i + 0.5) * size.x / nx - size.x * 0.5, height, (j + 0.5) * size.y / nz - size.y * 0.5)
			)
	# Shadows on the lights nearest the room centre only (style-guide light budget).
	var by_distance: Array[Vector3] = spots.duplicate()
	by_distance.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.length() < b.length())
	var scene: PackedScene = load(CEILING_LIGHT)
	var dead_scene: PackedScene = load(DEAD_LIGHT)
	var flicker: Array = state.get("flicker", [])
	var dead: Array = state.get("dead", [])
	for k: int in spots.size():
		var is_dead: bool = dead.has(float(k))
		var light: Node3D = (dead_scene if is_dead else scene).instantiate() as Node3D
		light.name = "Light%d" % k
		light.position = spots[k]
		# Tubes run along the room's long side.
		if size.x > size.y:
			light.rotation.y = PI * 0.5
		if not is_dead:
			(light as CeilingLight).casts_shadow = by_distance.find(spots[k]) < SHADOWED_LIGHTS_PER_ROOM
			(light as CeilingLight).flickers = flicker.has(float(k))
		lights.add_child(light)
		light.owner = root


static func _build_ramp(root: Node3D, parent: Node3D, ramp: Dictionary, index: int) -> void:
	var start: Vector3 = Vector3(ramp["from"][0], ramp["from"][1], ramp["from"][2])
	var end: Vector3 = Vector3(ramp["to"][0], ramp["to"][1], ramp["to"][2])
	var forward: Vector3 = (end - start).normalized()
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	var up: Vector3 = side.cross(forward).normalized()
	var size: Vector3 = Vector3(start.distance_to(end), 0.4, float(ramp["width"]))
	var block: Block = _block(root, parent, "Ramp%d" % index, size, Vector3.ZERO, "tiled_wet_floor")
	block.transform = Transform3D(Basis(forward, up, side), (start + end) * 0.5 - up * 0.2)


static func _block(root: Node3D, parent: Node3D, label: String, size: Vector3, at: Vector3, mat: String) -> Block:
	var block: Block = Block.new()
	block.name = label
	block.size = size
	block.material = load(MATERIALS % mat)
	block.position = at
	parent.add_child(block)
	block.owner = root
	return block


static func _child(root: Node3D, parent: Node3D, label: String) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = label
	parent.add_child(node)
	node.owner = root
	return node

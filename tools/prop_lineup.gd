## Renders one prop library family in rows under the Cold Containment interior light,
## with a 1.8 m figure (player capsule height) for scale. Families come from the
## catalogue's "Families" column in docs/design/prop-library.md.
##   xvfb-run -s "-screen 0 1600x900x24" godot --path . -s res://tools/prop_lineup.gd -- Barriers
## Saves screenshots/prop_lineup_<family>.png.
extends SceneTree

const STAGE: Script = preload("res://tools/lineup_stage.gd")
const LOOK: String = "res://levels/looks/halcyon_interior.tres"
const FLOOR: String = "res://levels/materials/raw_concrete.tres"
const CATALOGUE: String = "res://docs/design/prop-library.md"
const FIGURE_HEIGHT: float = 1.8
const MIN_ROW_WIDTH: float = 8.0
const ROWS: float = 3.0
const GAP: float = 0.6
const FOV: float = 40.0
## Camera pitch (up per metre back) and how much of the bounding sphere distance to keep: the wide frame fits
## the rows closer than the sphere.
const CAMERA_RISE: float = 0.8
const FRAMING: float = 0.65


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var family: String = args[0] if not args.is_empty() else "Barriers"
	var models: Array[String] = family_models(FileAccess.get_file_as_string(CATALOGUE), family)
	if models.is_empty():
		push_error("no catalogue rows in family '%s'" % family)
		quit(1)
		return
	var stage: Node3D = STAGE.build(LOOK)
	var extent: AABB = _place_rows(stage, models)
	var centre: Vector3 = extent.get_center()
	var ground: MeshInstance3D = STAGE.floor_plane(stage, FLOOR, Vector2(extent.size.x, extent.size.z) + Vector2(8, 8))
	ground.position = Vector3(centre.x, 0, centre.z)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color("#CDEEE8")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-30), 0)
	stage.add_child(sun)
	var reach: float = extent.size.length() + 6.0
	STAGE.light(stage, centre + Vector3(4, 3, extent.size.z * 0.5 + 3), 1.4, Color("#E8F6F2"), reach)
	STAGE.light(stage, centre + Vector3(0, 3, -extent.size.z * 0.5 - 3), 1.0, Color("#9FD8D0"), reach)
	var camera: Camera3D = STAGE.camera(stage)
	camera.fov = FOV
	root.add_child(stage)
	var distance: float = extent.size.length() * 0.5 / sin(deg_to_rad(FOV * 0.5)) * FRAMING
	camera.look_at_from_position(centre + Vector3(0, CAMERA_RISE, 1).normalized() * distance, centre)
	_run.call_deferred("res://screenshots/prop_lineup_%s.png" % family.to_snake_case())


## "folder/name" of every catalogue row whose Families cell names the family.
static func family_models(catalogue: String, family: String) -> Array[String]:
	var out: Array[String] = []
	for line: String in catalogue.split("\n"):
		var cells: PackedStringArray = line.split("|")
		if cells.size() < 8 or not cells[1].strip_edges().begins_with("`"):
			continue
		var families: PackedStringArray = cells[4].split(",")
		for name: String in families:
			if name.strip_edges() == family:
				out.append("%s/%s" % [cells[2].strip_edges(), cells[1].strip_edges().trim_prefix("`").trim_suffix("`")])
	return out


## Lays models left to right in about three rows (at least MIN_ROW_WIDTH m wide), figure first.
func _place_rows(stage: Node3D, models: Array[String]) -> AABB:
	var nodes: Array[Node3D] = [_figure()]
	for path: String in models:
		nodes.append((load("res://assets/models/%s.glb" % path) as PackedScene).instantiate() as Node3D)
	var boxes: Array[AABB] = []
	var total: float = 0.0
	for node: Node3D in nodes:
		stage.add_child(node)
		boxes.append(_bounds(node))
		total += boxes[-1].size.x + GAP
	var row_width: float = maxf(MIN_ROW_WIDTH, total / ROWS)
	var cursor: Vector3 = Vector3.ZERO
	var row_depth: float = 0.0
	var extent: AABB = AABB()
	for i: int in nodes.size():
		var box: AABB = boxes[i]
		if cursor.x > 0.0 and cursor.x + box.size.x > row_width:
			cursor = Vector3(0, 0, cursor.z - row_depth - GAP)
			row_depth = 0.0
		nodes[i].position = cursor - Vector3(box.position.x, 0, box.end.z)
		extent = extent.merge(AABB(cursor - Vector3(0, 0, box.size.z), box.size))
		cursor.x += box.size.x + GAP
		row_depth = maxf(row_depth, box.size.z)
	return extent


func _figure() -> Node3D:
	var body: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = FIGURE_HEIGHT
	body.mesh = capsule
	body.translate(Vector3(0, FIGURE_HEIGHT * 0.5, 0))
	var holder: Node3D = Node3D.new()
	holder.add_child(body)
	return holder


static func _bounds(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
		var part: MeshInstance3D = mesh as MeshInstance3D
		if part.mesh == null:
			continue
		var local: AABB = _relative(node, part) * part.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


static func _relative(top: Node3D, part: Node3D) -> Transform3D:
	var xform: Transform3D = Transform3D.IDENTITY
	var node: Node = part
	while node != top and node is Node3D:
		xform = (node as Node3D).transform * xform
		node = node.get_parent()
	return xform


func _run(out: String) -> void:
	await STAGE.save(self, out)
	quit()

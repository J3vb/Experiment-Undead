## Static display assembly for checking rigid gear against the shared player skeleton.
extends RefCounted

const GEAR: Array[String] = [
	"charm_dog_tags",
	"charm_vial",
	"charm_keycard",
	"charm_dosimeter",
	"charm_coin",
	"implant_reflex",
	"implant_lung",
	"implant_spine",
	"implant_ocular",
	"implant_relay",
]
const PLAYER: String = "res://assets/models/characters/player.glb"


static func build_character() -> Node3D:
	var display: Node3D = Node3D.new()
	display.name = "GearBoothCharacter"
	var player: Node3D = (load(PLAYER) as PackedScene).instantiate() as Node3D
	display.add_child(player)
	var skeleton: Skeleton3D = player.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var vest: Node3D = attach_vest(player, "medium")
	var clip: Node3D = vest.find_child("CharmClip", true, false) as Node3D
	var charm: Node3D = _gear("charm_keycard")
	clip.add_child(charm)
	var rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone("spine_03"))
	charm.basis = (rest.basis * clip.basis).inverse()
	var implant: Node3D = _gear("implant_ocular")
	var module: Node3D = implant.find_child("Module", true, false) as Node3D
	var port: Node3D = implant.find_child("Port", true, false) as Node3D
	module.get_parent().remove_child(module)
	port.get_parent().remove_child(port)
	implant.free()
	_attach_piece(skeleton, "forearm_L", module, Basis(Vector3.BACK, PI / 4.0))
	_attach_piece(skeleton, "neck", port, Basis.IDENTITY)
	return display


static func attach_vest(player: Node3D, frame: String) -> Node3D:
	var skeleton: Skeleton3D = player.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var vest: Node3D = _gear("vest_" + frame)
	vest.name = frame.capitalize() + "Vest"
	player.add_child(vest)
	var shell: MeshInstance3D = vest.find_child("Shell", true, false) as MeshInstance3D
	shell.skeleton = shell.get_path_to(skeleton)
	for node: Node in vest.find_children("*", "BoneAttachment3D", true, false):
		var attachment: BoneAttachment3D = node as BoneAttachment3D
		attachment.use_external_skeleton = true
		attachment.external_skeleton = attachment.get_path_to(skeleton)
	for cuff: String in ["CuffFP_L", "CuffFP_R"]:
		(vest.find_child(cuff, true, false) as MeshInstance3D).hide()
	return vest


static func _gear(id: String) -> Node3D:
	return (load("res://assets/models/gear/%s.glb" % id) as PackedScene).instantiate() as Node3D


static func _attachment(skeleton: Skeleton3D, bone: String, label: String) -> BoneAttachment3D:
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = label
	attachment.bone_name = bone
	attachment.bone_idx = skeleton.find_bone(bone)
	skeleton.add_child(attachment)
	return attachment


static func _attach_piece(skeleton: Skeleton3D, bone: String, piece: Node3D, facing: Basis) -> void:
	var attachment: BoneAttachment3D = _attachment(skeleton, bone, piece.name + "Attachment")
	attachment.add_child(piece)
	var rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	piece.transform = Transform3D(rest.basis.inverse() * facing, Vector3.ZERO)


static func build_lineup() -> Node3D:
	var lineup: Node3D = Node3D.new()
	lineup.name = "GearLineup"
	for index: int in GEAR.size():
		var piece: Node3D = _gear(GEAR[index])
		var holder: Node3D = Node3D.new()
		holder.name = GEAR[index]
		holder.rotation.y = -0.30
		lineup.add_child(holder)
		holder.add_child(piece)
		if GEAR[index].begins_with("implant_"):
			var port: Node3D = piece.find_child("Port", true, false) as Node3D
			port.position += Vector3(0.06, -0.10, 0.012)
		var bounds: AABB = _bounds(piece, piece.transform)
		var scale_factor: float = 0.43 / maxf(bounds.size.y, bounds.size.x)
		piece.scale = Vector3.ONE * scale_factor
		piece.position = -bounds.get_center() * scale_factor
		holder.position = Vector3((index % 5 - 2) * 0.64, 0.76 - (index / 5) * 0.77, 0)
		_plate(lineup, Vector3(0.59, 0.52, 0.018), holder.position + Vector3(0, 0, -0.10), "#1C2122", "Panel")
		_lineup_label(lineup, GEAR[index], holder.position + Vector3(0, -0.242, 0.04))
	return lineup


static func _bounds(node: Node3D, transform: Transform3D) -> AABB:
	var bounds: AABB = AABB()
	if node is MeshInstance3D:
		bounds = transform * (node as MeshInstance3D).get_aabb()
	for child: Node in node.get_children():
		if child is Node3D:
			var nested: Node3D = child as Node3D
			var child_bounds: AABB = _bounds(nested, transform * nested.transform)
			if child_bounds.size != Vector3.ZERO:
				bounds = child_bounds if bounds.size == Vector3.ZERO else bounds.merge(child_bounds)
	return bounds


static func _plate(parent: Node3D, size: Vector3, at: Vector3, color: String, label: String) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge: float = minf(minf(size.x, size.y), size.z) * 0.24
	var rings: Array[PackedVector3Array] = []
	for ring: int in 4:
		var inset: float = edge if ring == 0 or ring == 3 else 0.0
		var half: Vector2 = Vector2(size.x, size.y) / 2.0 - Vector2.ONE * inset
		var z: float = [-size.z / 2.0, -size.z / 2.0 + edge, size.z / 2.0 - edge, size.z / 2.0][ring]
		var corners: PackedVector3Array = []
		for point: Vector2 in [
			Vector2(-half.x + edge, -half.y),
			Vector2(half.x - edge, -half.y),
			Vector2(half.x, -half.y + edge),
			Vector2(half.x, half.y - edge),
			Vector2(half.x - edge, half.y),
			Vector2(-half.x + edge, half.y),
			Vector2(-half.x, half.y - edge),
			Vector2(-half.x, -half.y + edge),
		]:
			corners.append(Vector3(point.x, point.y, z))
		rings.append(corners)
	for ring: int in 3:
		for index: int in 8:
			var next: int = (index + 1) % 8
			_triangle(surface, rings[ring][index], rings[ring + 1][next], rings[ring][next])
			_triangle(surface, rings[ring][index], rings[ring + 1][index], rings[ring + 1][next])
	for index: int in range(1, 7):
		_triangle(surface, rings[0][0], rings[0][index], rings[0][index + 1])
		_triangle(surface, rings[3][0], rings[3][index + 1], rings[3][index])
	surface.generate_normals()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.72
	surface.set_material(material)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	mesh.position = at
	parent.add_child(mesh)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


static func _lineup_label(parent: Node3D, id: String, at: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = id.trim_prefix("charm_").trim_prefix("implant_").replace("_", " ").to_upper()
	label.font_size = 32
	label.pixel_size = 0.001
	label.modulate = Color("#D9D9D2")
	label.outline_size = 3
	label.position = at
	parent.add_child(label)

## Swaps worn gear on the shared body skeleton and keeps its owner in first person.
class_name GearRig
extends Node3D

signal look_changed(look: CharacterLook)

@export var body: Node3D
@export var pitch_source: Node3D

var skeleton: Skeleton3D
var _attachments: Array[Node3D] = []
var _owner_view: bool = false
var _head: int = -1
var _head_rest: Quaternion
var _head_axis: Quaternion


func _ready() -> void:
	skeleton = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_head = skeleton.find_bone("head")
	_head_rest = skeleton.get_bone_pose_rotation(_head)
	_head_axis = skeleton.get_bone_global_rest(_head).basis.get_rotation_quaternion()
	# The source rig has no idle clip. Lower its A-pose arms to a relaxed stance.
	_lower_arm(&"upperarm_L", -PI / 4.0)
	_lower_arm(&"upperarm_R", PI / 4.0)
	set_process(pitch_source != null)


func _lower_arm(bone_name: StringName, angle: float) -> void:
	var bone: int = skeleton.find_bone(bone_name)
	var axis: Quaternion = skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	var turn: Quaternion = axis.inverse() * Quaternion(Vector3.BACK, angle) * axis
	skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * turn)


func _process(_delta: float) -> void:
	var turn: Quaternion = _head_axis.inverse() * Quaternion(Vector3.RIGHT, -pitch_source.rotation.x) * _head_axis
	skeleton.set_bone_pose_rotation(_head, _head_rest * turn)


func set_owner_view(value: bool) -> void:
	_owner_view = value
	_set_geometry(body)


func apply(look: CharacterLook) -> void:
	for attachment: Node3D in _attachments:
		attachment.free()
	_attachments.clear()
	for slot: StringName in CharacterLook.SLOTS:
		if not look.slots.has(slot):
			continue
		var entry: Dictionary = look.slots[slot]
		var visual: GearVisual = GearVisual.find(entry.get("visual_id", &""))
		var rarity: StringName = entry.get("rarity", &"common")
		if visual == null or visual.slot != slot:
			visual = GearVisual.fallback(slot)
			rarity = &"common"
		var piece: Node3D = _attach(visual)
		if not Content.has(&"looks", rarity):
			rarity = &"common"
		var finish: RarityLook = Content.get_item(&"looks", rarity) as RarityLook
		var dyes: Array = entry.get("dyes", [CharacterLook.DEFAULT_DYE_MAIN, CharacterLook.DEFAULT_DYE_ACCENT])
		GearLook.apply(piece, finish, dyes[0], dyes[1])
		_set_geometry(piece)
	look_changed.emit(look)


func _attach(visual: GearVisual) -> Node3D:
	var piece: Node3D = visual.scene.instantiate() as Node3D
	if visual.slot == &"vest":
		_bind_vest(piece)
		return piece
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = String(visual.slot).capitalize()
	attachment.bone_name = visual.attach
	skeleton.add_child(attachment)
	attachment.transform = skeleton.get_bone_global_pose(skeleton.find_bone(visual.attach))
	_attachments.append(attachment)
	attachment.add_child(piece)
	if visual.slot == &"charm":
		var rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone(visual.attach))
		piece.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, Vector3(0.105, 1.38, 0.215))
	else:
		_bind_implant(piece)
	return piece


func _bind_vest(piece: Node3D) -> void:
	# Imported vest vertices and bind poses use skeleton space, so the vest sits in
	# a fixed holder: a bone attachment would move the skin a second time.
	var holder: Node3D = Node3D.new()
	holder.name = "Vest"
	skeleton.add_child(holder)
	_attachments.append(holder)
	holder.add_child(piece)
	var shell: MeshInstance3D = piece.find_child("Shell", true, false) as MeshInstance3D
	shell.skeleton = shell.get_path_to(skeleton)
	for node: Node in piece.find_children("*", "BoneAttachment3D", true, false):
		var socket: BoneAttachment3D = node as BoneAttachment3D
		socket.use_external_skeleton = true
		socket.external_skeleton = socket.get_path_to(skeleton)
	for cuff: String in ["CuffFP_L", "CuffFP_R"]:
		piece.find_child(cuff, true, false).queue_free()


func _bind_implant(piece: Node3D) -> void:
	var rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone("forearm_L"))
	piece.basis = rest.basis.inverse() * Basis(Vector3.BACK, PI / 4.0)
	var port: Node3D = piece.find_child("Port", true, false) as Node3D
	var neck: BoneAttachment3D = BoneAttachment3D.new()
	neck.name = "NeckPort"
	neck.bone_name = &"neck"
	piece.add_child(neck)
	neck.external_skeleton = neck.get_path_to(skeleton)
	neck.use_external_skeleton = true
	port.reparent(neck, false)
	port.basis = skeleton.get_bone_global_rest(skeleton.find_bone("neck")).basis.inverse()


func _set_geometry(root: Node) -> void:
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			if _owner_view
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		)

## Fixed character inspection cameras using the gear booth lights and imported runtime finishes.
extends Node3D

const PLAYER: String = "res://assets/models/characters/player.glb"
const ARMS: String = "res://assets/models/characters/player_arms.glb"
const VEST: String = "res://assets/models/gear/vest_medium.glb"
const ASSEMBLY: Script = preload("res://tools/gear_booth_assembly.gd")
const RARITIES: Array[String] = ["common", "legendary"]
const RIFLE_POSITION: Vector3 = Vector3(0.17, -0.18, -0.34)

var _booth: Node3D
var _camera: Camera3D
var _label: Label
var _model: Node3D
var _out: String


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else "res://screenshots/character_review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_booth = (load("res://tools/gear_booth.tscn") as PackedScene).instantiate() as Node3D
	_booth.set_script(null)
	add_child(_booth)
	_camera = _booth.get_node("Turntable/Camera3D") as Camera3D
	_label = _booth.get_node("Caption/Label") as Label
	(_booth.get_node("Turntable") as Node3D).transform = Transform3D.IDENTITY
	_capture.call_deferred()


func _show(path: String) -> Skeleton3D:
	if _model != null:
		_model.free()
	_model = (load(path) as PackedScene).instantiate() as Node3D
	add_child(_model)
	return _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D


func _look(rarity: String) -> void:
	var look: RarityLook = load("res://content/looks/rarity/%s.tres" % rarity) as RarityLook
	GearLook.apply(_model, look, Color.WHITE, Color.WHITE)
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).set_instance_shader_parameter(&"pulse_seconds", 0.0)


func _shot(name: String, caption: String) -> void:
	_label.text = caption
	for _frame: int in 12:
		await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(_out).path_join(name + ".png")
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Cannot save character inspection: " + path)
		get_tree().quit(1)


func _capture() -> void:
	if not "--rifle-only" in OS.get_cmdline_user_args():
		await _body_views()
		await _arms_views()
	await _first_person()
	print("Character inspection saved to ", _out)
	get_tree().quit()


func _body_views() -> void:
	_show(PLAYER)
	_camera.fov = 36.0
	_camera.position = Vector3(0, 1.0, 3.5)
	_camera.look_at(Vector3(0, 0.9, 0))
	for rarity: String in RARITIES:
		_look(rarity)
		await _shot("body_" + rarity, "UNDERSUIT / " + rarity.to_upper() + " / BOOTH")
	await _silhouette("body_silhouette")
	_show(PLAYER)
	_look("common")
	_camera.position = Vector3(0.25, 1.73, 0.68)
	_camera.look_at(Vector3(0, 1.69, 0))
	await _shot("body_head", "BALACLAVA / GOGGLES / COMMON / BOOTH CLOSE-UP")
	_camera.position = Vector3(0.38, 0.29, 0.80)
	_camera.look_at(Vector3(0, 0.20, 0))
	await _shot("body_boots", "BOOTS / COMMON / BOOTH CLOSE-UP")
	_show(PLAYER)
	ASSEMBLY.attach_vest(_model, "medium")
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = 110.0
	var world: WorldEnvironment = _booth.get_node("WorldEnvironment") as WorldEnvironment
	world.environment.fog_enabled = true
	for distance: float in [10.0, 30.0]:
		_camera.position = Vector3(0, 1.1, distance)
		_camera.look_at(Vector3(0, 1.1, 0))
		for rarity: String in RARITIES:
			_look(rarity)
			var name: String = "body_%dm_%s" % [distance, rarity]
			await _shot(name, "%d M / 110 DEG HFOV / %s / MEDIUM VEST" % [distance, rarity.to_upper()])
	world.environment.fog_enabled = false


func _silhouette(name: String) -> void:
	var black: StandardMaterial3D = StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = black
	var world: WorldEnvironment = _booth.get_node("WorldEnvironment") as WorldEnvironment
	var background: Color = world.environment.background_color
	world.environment.background_color = Color("#D9D9D2")
	(_booth.get_node("Floor") as MeshInstance3D).hide()
	await _shot(name, "BLACK SILHOUETTE / FIXED CAMERA")
	world.environment.background_color = background
	(_booth.get_node("Floor") as MeshInstance3D).show()


func _arms_views() -> void:
	_show(ARMS)
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.fov = 36.0
	_camera.position = Vector3(0.0, 1.28, 1.85)
	_camera.look_at(Vector3(0.0, 1.17, 0))
	for rarity: String in RARITIES:
		_look(rarity)
		await _shot("arms_" + rarity, "PLAYER ARMS / " + rarity.to_upper() + " / BOOTH")
	await _silhouette("arms_silhouette")


static func _convert(value: Vector3) -> Vector3:
	return Vector3(value.x, value.z, -value.y)


static func _basis(direction: Vector3, dorsal: Vector3) -> Basis:
	var axis: Vector3 = direction.normalized()
	var outward: Vector3 = (dorsal - axis * dorsal.dot(axis)).normalized()
	return Basis(outward.cross(axis), outward, axis)


static func _pose(skeleton: Skeleton3D, bone: String, at: Vector3, direction: Vector3, dorsal: Vector3) -> void:
	var index: int = skeleton.find_bone(bone)
	var rest: Transform3D = skeleton.get_bone_global_rest(index)
	var rotation: Basis = (
		_basis(_convert(direction), _convert(dorsal)) * _basis(rest.basis.y, Vector3.FORWARD).inverse()
	)
	skeleton.set_bone_global_pose(index, Transform3D(rotation * rest.basis, _convert(at)))


static func _pose_arm(
	skeleton: Skeleton3D, side: String, shoulder: Vector3, wrist: Vector3, bend: Vector3, dorsal: Vector3 = Vector3.ZERO
) -> void:
	var upper: float = skeleton.get_bone_rest(skeleton.find_bone("forearm_" + side)).origin.length()
	var forearm: float = skeleton.get_bone_rest(skeleton.find_bone("hand_" + side)).origin.length()
	var direction: Vector3 = (wrist - shoulder).normalized()
	var distance: float = (wrist - shoulder).length()
	var along: float = (upper * upper - forearm * forearm + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, upper * upper - along * along))
	var elbow: Vector3 = shoulder + direction * along + (bend - direction * bend.dot(direction)).normalized() * height
	if dorsal == Vector3.ZERO:
		dorsal = Vector3(0.7, -0.2, 0.7) if side == "R" else Vector3(0, 0, 1)
	_pose(skeleton, "upperarm_" + side, shoulder, elbow - shoulder, dorsal)
	_pose(skeleton, "forearm_" + side, elbow, wrist - elbow, dorsal)
	if side == "R":
		_pose(skeleton, "hand_R", wrist, Vector3(0.10, 0.95, -0.30), Vector3(0.7, -0.2, 0.7))
	else:
		_pose(skeleton, "hand_L", wrist, Vector3(0.8, 0.45, 0.25), Vector3(-0.3, -0.3, 1))


static func _rifle_arm(skeleton: Skeleton3D, side: String) -> void:
	var right: bool = side == "R"
	var sign_x: float = -1.0 if right else 1.0
	var direction: Vector3 = Vector3(0, sqrt(0.75), 0.5) if right else Vector3(0.8 * sqrt(0.96), 0.6 * sqrt(0.96), 0.2)
	var dorsal: Vector3 = Vector3.RIGHT if right else Vector3(0.16, 0.12, -sqrt(0.96))
	var rest_direction: Vector3 = Vector3(sign_x, 0, -1).normalized()
	var rotation: Basis = _basis(direction, dorsal) * _basis(rest_direction, Vector3(0, 1, 0)).inverse()
	var source_center: Vector3 = Vector3(sign_x * 0.675, -0.045 if right else -0.057, 0.985)
	var source_wrist: Vector3 = Vector3(sign_x * 0.61, 0, 1.05)
	var gun_center: Vector3 = Vector3(0, -0.129, -0.111) if right else Vector3(0, 0.220, 0.016)
	var weapon_offset: Vector3 = Vector3(RIFLE_POSITION.x, -RIFLE_POSITION.z, RIFLE_POSITION.y)
	var wrist: Vector3 = weapon_offset + gun_center - rotation * (source_center - source_wrist)
	var shoulder: Vector3 = Vector3(0.19, -0.115, -0.234) if right else Vector3(-0.14, 0.03, -0.234)
	# The elbow circle point opposite the palm axis gives the smallest wrist bend.
	var bend: Vector3 = -direction
	_pose_arm(skeleton, side, shoulder, wrist, bend, dorsal)
	_pose(skeleton, "hand_" + side, wrist, direction, dorsal)


func _cuffs(skeleton: Skeleton3D) -> void:
	var vest: Node3D = (load(VEST) as PackedScene).instantiate() as Node3D
	for side: String in ["L", "R"]:
		var cuff: Node3D = vest.find_child("CuffFP_" + side, true, false) as Node3D
		var rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone("forearm_" + side))
		var offset: Transform3D = rest.affine_inverse() * cuff.transform
		cuff.get_parent().remove_child(cuff)
		cuff.owner = null
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.bone_name = "forearm_" + side
		skeleton.add_child(attachment)
		attachment.add_child(cuff)
		cuff.transform = offset
	vest.free()


func _first_person() -> void:
	var skeleton: Skeleton3D = _show(ARMS)
	_rifle_arm(skeleton, "R")
	_rifle_arm(skeleton, "L")
	_cuffs(skeleton)
	var rifle: Node3D = (load("res://assets/models/weapons/rifle_ar.glb") as PackedScene).instantiate() as Node3D
	add_child(rifle)
	rifle.position = RIFLE_POSITION
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = 110.0
	_camera.position = Vector3.ZERO
	_camera.rotation = Vector3.ZERO
	(_booth.get_node("Floor") as MeshInstance3D).hide()
	for rarity: String in RARITIES:
		_look(rarity)
		await _shot("fp_" + rarity, "RIFLE INSPECTION / 110 DEG HFOV / " + rarity.to_upper() + " / MEDIUM CUFFS")
	await _shot("fp_rifle", "INSPECTION POSE / 110 DEG HFOV / LEGENDARY / RIFLE HIP POSITION")
	_camera.fov = 45.0
	_camera.position = Vector3(0.45, -0.29, -0.50)
	_camera.look_at(Vector3(0.17, -0.29, -0.21))
	await _shot("grip_right", "RIGHT GRIP / LEGENDARY / UNMODIFIED RIFLE")
	_camera.position = Vector3(0.29, -0.50, -0.65)
	_camera.look_at(Vector3(0.17, -0.19, -0.56))
	await _shot("grip_left", "LEFT SUPPORT / LEGENDARY / UNMODIFIED HANDGUARD")
	_camera.fov = 60.0
	_camera.position = Vector3(0.17, 0.95, -0.43)
	_camera.look_at(Vector3(0.17, -0.20, -0.43), Vector3.FORWARD)
	await _shot("grip_top", "CONTACT CHECK / TOP / UNMODIFIED RIFLE")
	_camera.position = Vector3(0.17, -1.35, -0.43)
	_camera.look_at(Vector3(0.17, -0.20, -0.43), Vector3.FORWARD)
	await _shot("grip_under", "CONTACT CHECK / UNDERSIDE / UNMODIFIED RIFLE")
	_camera.position = Vector3(1.1, -0.18, -0.23)
	_camera.look_at(Vector3(0, -0.30, -0.23))
	await _shot("pose_side", "WHOLE ARM POSE / FIXED SIDE CAMERA / UNMODIFIED RIFLE")

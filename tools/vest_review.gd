## Captures each worn vest with fixed booth lighting, poses, distances and silhouette views.
## godot --path . tools/vest_review.tscn -- --out screenshots/vest_review
extends Node3D

const BOOTH: PackedScene = preload("res://tools/gear_booth.tscn")
const ASSEMBLY: Script = preload("res://tools/gear_booth_assembly.gd")
const FRAMES: Array[String] = ["light", "medium", "heavy"]
const RARITIES: Array[String] = ["common", "legendary"]
const VIEWS: Dictionary[String, float] = {"front": 0.0, "three_quarter": 45.0, "side": 90.0, "back": 180.0}
const SIZE: Vector2i = Vector2i(1280, 720)

var _out: String = ""
var _booth: Node3D
var _player: Node3D
var _vest: Node3D
var _camera: Camera3D
var _turntable: Node3D
var _label: Label
var _environment: Environment


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--out" or args[1].is_empty():
		push_error("Vest review expects --out <directory>")
		get_tree().quit(1)
		return
	_out = ProjectSettings.globalize_path(args[1])
	if DisplayServer.get_name() == "headless" or DirAccess.make_dir_recursive_absolute(_out) != OK:
		push_error("Vest review needs a display and a writable output directory")
		get_tree().quit(1)
		return
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_size = SIZE
	get_window().size = SIZE
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_booth = BOOTH.instantiate() as Node3D
	_booth.set_script(null)
	add_child(_booth)
	_camera = _booth.get_node("Turntable/Camera3D") as Camera3D
	_turntable = _booth.get_node("Turntable") as Node3D
	_label = _booth.get_node("Caption/Label") as Label
	_label.offset_bottom = 96.0
	var world: WorldEnvironment = _booth.get_node("WorldEnvironment") as WorldEnvironment
	world.environment = world.environment.duplicate() as Environment
	_environment = world.environment
	_render.call_deferred()


static func apply_pose(player: Node3D, bent: bool) -> void:
	var skeleton: Skeleton3D = player.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	skeleton.reset_bone_poses()
	if not bent:
		return
	var angles: Dictionary[String, float] = {
		"spine_01": 12.0, "spine_02": 12.0, "spine_03": 8.0, "neck": -12.0, "forearm_L": 35.0, "forearm_R": 35.0
	}
	for bone: String in angles:
		var index: int = skeleton.find_bone(bone)
		var axis: Vector3 = skeleton.get_bone_global_rest(index).basis.inverse() * Vector3.RIGHT
		var rotation: Quaternion = skeleton.get_bone_pose_rotation(index)
		skeleton.set_bone_pose_rotation(index, rotation * Quaternion(axis.normalized(), deg_to_rad(angles[bone])))
	skeleton.force_update_all_bone_transforms()


static func frame_camera(camera: Camera3D, orbit: Node3D, distance: float, angle: float) -> void:
	orbit.position = Vector3(0.0, 1.30 if distance < 2.0 else 0.95, 0.0)
	orbit.rotation = Vector3(0.0, deg_to_rad(angle), 0.0)
	camera.keep_aspect = Camera3D.KEEP_WIDTH if distance >= 10.0 else Camera3D.KEEP_HEIGHT
	camera.fov = 110.0 if distance >= 10.0 else 36.0
	camera.position = Vector3(0.0, 0.0, distance)
	camera.rotation = Vector3.ZERO


func _show(frame: String) -> void:
	if _player != null:
		_player.free()
	_player = (load(ASSEMBLY.PLAYER) as PackedScene).instantiate() as Node3D
	add_child(_player)
	_vest = ASSEMBLY.attach_vest(_player, frame)
	var common: RarityLook = load("res://content/looks/rarity/common.tres") as RarityLook
	GearLook.apply(_player, common, Color.WHITE, Color.WHITE)


func _render() -> void:
	for frame: String in FRAMES:
		_show(frame)
		for rarity: String in RARITIES:
			var look: RarityLook = load("res://content/looks/rarity/%s.tres" % rarity) as RarityLook
			for pose: String in ["rest", "bent"]:
				GearLook.apply(_vest, look, Color.WHITE, Color.WHITE)
				_environment.fog_enabled = false
				apply_pose(_player, pose == "bent")
				var prefix: String = "vest_%s_%s_%s" % [frame, rarity, pose]
				for view: String in VIEWS:
					frame_camera(_camera, _turntable, 1.65, VIEWS[view])
					if not await _capture(prefix + "_close_" + view):
						return
				if not await _distance_views(prefix):
					return
		if not await _silhouettes(frame):
			return
	print("Vest review saved captures to ", _out)
	get_tree().quit()


func _distance_views(prefix: String) -> bool:
	for node: Node in _vest.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).set_instance_shader_parameter(&"glow_strength", 0.0)
	for distance: float in [10.0, 30.0]:
		_environment.fog_enabled = distance >= 30.0
		for view: String in ["front", "back"]:
			frame_camera(_camera, _turntable, distance, VIEWS[view])
			if not await _capture(prefix + "_%dm_" % int(distance) + view):
				return false
	return true


func _silhouettes(frame: String) -> bool:
	var black: StandardMaterial3D = StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	for node: Node in _player.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = black
	var world: WorldEnvironment = _booth.get_node("WorldEnvironment") as WorldEnvironment
	var original: Environment = world.environment
	world.environment = original.duplicate() as Environment
	world.environment.fog_enabled = false
	world.environment.background_color = Color("#D9D9D2")
	(_booth.get_node("Floor") as MeshInstance3D).hide()
	for pose: String in ["rest", "bent"]:
		apply_pose(_player, pose == "bent")
		for distance: float in [3.4, 30.0]:
			for view: String in ["front", "side", "back"]:
				frame_camera(_camera, _turntable, distance, VIEWS[view])
				var range_name: String = "full" if distance < 10.0 else "30m"
				if not await _capture("vest_%s_silhouette_%s_%s_%s" % [frame, pose, range_name, view]):
					return false
	world.environment = original
	(_booth.get_node("Floor") as MeshInstance3D).show()
	return true


func _capture(filename: String) -> bool:
	_label.text = filename.replace("_", " ").to_upper()
	if filename.contains("10m") or filename.contains("30m"):
		_label.text += "\n110 DEG HORIZONTAL FOV"
		if not filename.contains("silhouette"):
			_label.text += " / GLOW OFF"
	if filename.contains("30m") and not filename.contains("silhouette"):
		_label.text += " / FOG"
	for _frame: int in 12:
		await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png(_out.path_join(filename + ".png"))
	if error != OK:
		push_error("Cannot save vest review image: " + filename)
		get_tree().quit(error)
	return error == OK

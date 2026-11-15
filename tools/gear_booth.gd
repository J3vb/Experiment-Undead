## Renders models in the warm Lantern Post booth; --lineup/--rarities/--distance show worn vest frames.
## godot --path . --rendering-driver opengl3 tools/gear_booth.tscn -- --out screenshots/gear --rarity all
extends Node3D

const MODELS: Array[String] = [
	"res://assets/models/characters/player.glb",
]
const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary", "prototype"]
const VIEWS: Dictionary[String, float] = {"front": 0.0, "three_quarter": 45.0, "side": 90.0, "back": 180.0}
const SIZE: Vector2i = Vector2i(1280, 720)
const WARMUP_FRAMES: int = 12
const FRAMES: Array[String] = ["light", "medium", "heavy"]
const CAPTURES: Array[String] = ["--medium", "--lineup", "--rarities", "--distance"]

var _out: String = ""
var _rarity: String = "common"
var _model: Node3D
var _capture_mode: String = ""

@onready var _turntable: Node3D = $Turntable
@onready var _camera: Camera3D = $Turntable/Camera3D
@onready var _label: Label = $Caption/Label


func _ready() -> void:
	if not _read_arguments(OS.get_cmdline_user_args()):
		get_tree().quit(1)
		return
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_size = SIZE
	get_window().size = SIZE
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not _capture_mode.is_empty():
		set_process(false)
		_render_lineup.call_deferred()
		return
	if not _show_model(MODELS[0]):
		get_tree().quit(1)
		return
	if _out.is_empty():
		_apply_rarity(_rarity if _rarity != "all" else RARITIES[0])
	else:
		set_process(false)
		_render.call_deferred()


func _process(delta: float) -> void:
	_turntable.rotation.y += delta * 0.22


func _read_arguments(args: PackedStringArray) -> bool:
	var index: int = 0
	while index < args.size():
		var option: String = args[index]
		if option in CAPTURES:
			if CAPTURES.find(option) > CAPTURES.find(_capture_mode):
				_capture_mode = option
			index += 1
			continue
		if option not in ["--out", "--rarity"] or index + 1 >= args.size():
			push_error(
				"Gear booth expects --out <directory> [--rarity common|uncommon|rare|epic|legendary|prototype|all]"
			)
			return false
		var value: String = args[index + 1]
		if value.is_empty() or value.begins_with("--"):
			push_error("Gear booth option %s needs a value" % option)
			return false
		if option == "--out":
			_out = value
		else:
			_rarity = value
		index += 2
	if _rarity != "all" and _rarity not in RARITIES:
		push_error("Unknown gear booth rarity: " + _rarity)
		return false
	return true


func _show_model(path: String) -> bool:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("Gear booth cannot load model: " + path)
		return false
	if _model != null:
		_model.free()
	_model = packed.instantiate() as Node3D
	if _model == null:
		push_error("Gear booth model needs a Node3D root: " + path)
		return false
	add_child(_model)
	if path == MODELS[0]:
		_attach_vest(_model, "medium")
	_frame_model()
	return true


func _attach_vest(player: Node3D, frame: String) -> void:
	var skeleton: Skeleton3D = player.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var packed: PackedScene = load("res://assets/models/gear/vest_%s.glb" % frame) as PackedScene
	var vest: Node3D = packed.instantiate() as Node3D
	player.add_child(vest)
	var shell: MeshInstance3D = vest.find_child("Shell", true, false) as MeshInstance3D
	shell.skeleton = shell.get_path_to(skeleton)
	for node: Node in vest.find_children("*", "BoneAttachment3D", true, false):
		var attachment: BoneAttachment3D = node as BoneAttachment3D
		attachment.use_external_skeleton = true
		attachment.external_skeleton = attachment.get_path_to(skeleton)
	for cuff: String in ["CuffFP_L", "CuffFP_R"]:
		(vest.find_child(cuff, true, false) as MeshInstance3D).hide()


func _render_lineup() -> void:
	_model = Node3D.new()
	_model.name = "VestFrames"
	add_child(_model)
	var count: int = 6 if _capture_mode == "--rarities" else (1 if _capture_mode == "--medium" else 3)
	for index: int in count:
		var frame: String = FRAMES[index] if count == 3 else "medium"
		var rarity: String = RARITIES[index] if count == 6 else "common"
		var player: Node3D = (load(MODELS[0]) as PackedScene).instantiate() as Node3D
		_model.add_child(player)
		player.position.x = (index - (count - 1) * 0.5) * 1.65
		_attach_vest(player, frame)
		var look: RarityLook = load("res://content/looks/rarity/%s.tres" % rarity) as RarityLook
		GearLook.apply(player, look, Color.WHITE, Color.WHITE)
		_lineup_label(rarity.capitalize() if count == 6 else frame.capitalize(), player.position.x, look.trim_color)
	_lineup_camera(count)
	var filename: String = "gear_" + _capture_mode.trim_prefix("--")
	if _capture_mode == "--lineup":
		filename = "gear_frames"
	elif _capture_mode == "--distance":
		filename = "gear_30m"
	_label.text = filename.replace("_", " ").to_upper()
	if _capture_mode == "--distance":
		_label.text += " / 30 M / 110 DEG HORIZONTAL FOV"
	await _capture_lineup(filename)


func _lineup_camera(count: int) -> void:
	_turntable.position = Vector3(0, 1.05 if count > 1 else 1.30, 0)
	_turntable.rotation = Vector3.ZERO
	var span: float = 5.65 if count == 6 else (3.5 if count == 3 else 1.5)
	_camera.fov = rad_to_deg(2.0 * atan(span / 16.0))
	_camera.position = Vector3(0.15 if count == 1 else 0.0, 0.12, 8)
	if _capture_mode == "--distance":
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
		_camera.fov = 110.0
		_camera.position = Vector3(0, 0, 30)
		var world: WorldEnvironment = $WorldEnvironment
		world.environment = world.environment.duplicate() as Environment
		world.environment.fog_enabled = true
	_camera.look_at(_turntable.global_position)


func _lineup_label(text: String, x: float, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = 42
	label.pixel_size = 0.0018
	label.modulate = color
	label.position = Vector3(x, -0.14, 0.1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	_model.add_child(label)


func _capture_lineup(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Gear booth PNG capture needs a display; use xvfb-run with opengl3 on a cloud machine")
		get_tree().quit(1)
		return
	var directory: String = ProjectSettings.globalize_path(_out if not _out.is_empty() else "res://screenshots")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Gear booth cannot create output directory: " + directory)
		get_tree().quit(1)
		return
	for _frame: int in WARMUP_FRAMES:
		await RenderingServer.frame_post_draw
	var path: String = directory.path_join(filename + ".png")
	if get_viewport().get_texture().get_image().save_png(path) != OK:
		push_error("Gear booth cannot save " + path)
		get_tree().quit(1)
		return
	print("Gear booth saved ", path)
	get_tree().quit()


func _frame_model() -> void:
	var bounds: AABB = AABB()
	var first: bool = true
	var meshes: Array[Node] = _model.find_children("*", "MeshInstance3D", true, false)
	if _model is MeshInstance3D:
		meshes.push_front(_model)
	for node: Node in meshes:
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var center: Vector3 = bounds.get_center()
	_model.position -= Vector3(center.x, bounds.position.y, center.z)
	_turntable.position = Vector3(0.0, maxf(bounds.size.y * 0.5, 0.05), 0.0)
	_turntable.rotation = Vector3.ZERO
	var radius: float = Vector2(bounds.size.x, bounds.size.z).length() * 0.5
	var span: float = maxf(bounds.size.y, radius * 2.0 / (float(SIZE.x) / SIZE.y))
	var distance: float = maxf(span * 0.6 / tan(deg_to_rad(_camera.fov * 0.5)) + radius, 0.2)
	_camera.position = Vector3(0.0, span * 0.05, distance)
	_camera.look_at(_turntable.global_position)


func _apply_rarity(rarity: String) -> void:
	var look: RarityLook = load("res://content/looks/rarity/%s.tres" % rarity) as RarityLook
	GearLook.apply(_model, look, Color.WHITE, Color.WHITE)
	_label.text = "%s  /  %s" % [_model.name, rarity.capitalize()]


func _render() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Gear booth PNG capture needs a display; use xvfb-run with opengl3 on a cloud machine")
		get_tree().quit(1)
		return
	var directory: String = ProjectSettings.globalize_path(_out)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Gear booth cannot create output directory: " + directory)
		get_tree().quit(1)
		return
	var rarities: Array[String] = RARITIES if _rarity == "all" else [_rarity]
	for path: String in MODELS:
		if not _show_model(path) or not await _render_model(path.get_file().get_basename(), rarities, directory):
			get_tree().quit(1)
			return
	get_tree().quit()


func _render_model(model_name: String, rarities: Array[String], directory: String) -> bool:
	var sheet: Image = Image.create(SIZE.x * VIEWS.size(), SIZE.y * rarities.size(), false, Image.FORMAT_RGB8)
	for row: int in rarities.size():
		var rarity: String = rarities[row]
		_apply_rarity(rarity)
		var column: int = 0
		for view: String in VIEWS:
			_turntable.rotation.y = deg_to_rad(VIEWS[view])
			_label.text = "%s  /  %s  /  %s" % [model_name.capitalize(), rarity.capitalize(), view.replace("_", " ")]
			for _frame: int in WARMUP_FRAMES:
				await RenderingServer.frame_post_draw
			var shot: Image = get_viewport().get_texture().get_image()
			shot.convert(Image.FORMAT_RGB8)
			var filename: String = "%s_%s_%s.png" % [model_name, rarity, view]
			if shot.save_png(directory.path_join(filename)) != OK:
				push_error("Gear booth cannot save " + directory.path_join(filename))
				return false
			sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, SIZE), Vector2i(column * SIZE.x, row * SIZE.y))
			column += 1
	var sheet_path: String = directory.path_join("%s_rarities.png" % model_name)
	if sheet.save_png(sheet_path) != OK:
		push_error("Gear booth cannot save " + sheet_path)
		return false
	print("Gear booth saved %d views and %s" % [rarities.size() * VIEWS.size(), sheet_path])
	return true

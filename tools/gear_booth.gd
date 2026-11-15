## Renders worn vest frames, rigid gear close-ups, or a fully dressed player in the Lantern Post booth.
## godot --path . --rendering-driver opengl3 tools/gear_booth.tscn -- --out screenshots/gear --rarity all
extends Node3D

const ASSEMBLY: Script = preload("res://tools/gear_booth_assembly.gd")
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
var _mode: String = "models"
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
	if not _show_mode():
		get_tree().quit(1)
		return
	if _out.is_empty():
		_apply_rarity(_rarity_rows()[0])
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
		if option not in ["--out", "--rarity", "--mode"] or index + 1 >= args.size():
			push_error("Gear booth expects --out <directory> [--rarity <name>|all] [--mode models|lineup|character]")
			return false
		var value: String = args[index + 1]
		if value.is_empty() or value.begins_with("--"):
			push_error("Gear booth option %s needs a value" % option)
			return false
		if option == "--out":
			_out = value
		elif option == "--rarity":
			_rarity = value
		else:
			_mode = value
		index += 2
	if _mode not in ["models", "lineup", "character"]:
		push_error("Unknown gear booth mode: " + _mode)
		return false
	if _rarity != "all" and _rarity not in RARITIES:
		push_error("Unknown gear booth rarity: " + _rarity)
		return false
	return true


func _show_mode() -> bool:
	if _mode == "models":
		return _show_model(MODELS[0])
	_model = ASSEMBLY.build_lineup() if _mode == "lineup" else ASSEMBLY.build_character()
	add_child(_model)
	_frame_model()
	if _mode == "lineup":
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = 2.0
		($Floor as MeshInstance3D).visible = false
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
		ASSEMBLY.attach_vest(_model, "medium")
	_frame_model()
	return true


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
		ASSEMBLY.attach_vest(player, frame)
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
	if _mode != "models":
		for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
			if node.name in ["Module", "Port"] or node.find_parent("charm_vial") != null:
				(node as MeshInstance3D).set_instance_shader_parameter(&"glow_color", Color("#8DFF3A"))
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
	if _mode != "models":
		await _render_display(directory)
		return
	var rarities: Array[String] = _rarity_rows()
	for path: String in MODELS:
		if not _show_model(path) or not await _render_model(path.get_file().get_basename(), rarities, directory):
			get_tree().quit(1)
			return
	get_tree().quit()


func _rarity_rows() -> Array[String]:
	if _rarity == "all":
		return RARITIES
	return [_rarity]


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


func _render_display(directory: String) -> void:
	_apply_rarity(_rarity_rows()[0])
	_turntable.rotation.y = deg_to_rad(25.0) if _mode == "character" else 0.0
	_label.text = (
		"FIELD GEAR / ECONOMY + LUCK / ABILITIES" if _mode == "lineup" else "MEDIUM VEST / OCULAR / HALCYON KEYCARD"
	)
	for _frame: int in WARMUP_FRAMES:
		await RenderingServer.frame_post_draw
	var filename: String = directory.path_join("gear_%s.png" % _mode)
	var error: Error = get_viewport().get_texture().get_image().save_png(filename)
	if error != OK:
		push_error("Gear booth cannot save " + filename)
	else:
		print("Gear booth saved ", filename)
	get_tree().quit(error)

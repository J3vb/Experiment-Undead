## Renders vests on the shared player skeleton: --rarities, --lineup, --distance or a medium close view.
## xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/gear_booth.gd -- --rarities
extends SceneTree

const PLAYER: String = "res://assets/models/characters/player.glb"
const FRAMES: Array[String] = ["light", "medium", "heavy"]
const RARITIES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Prototype"]
const TRIMS: Array[Color] = [
	Color("#D9D9D2"), Color("#3FE0C8"), Color("#3D7DFF"), Color("#A64DFF"), Color("#FF8A1C"), Color("#8DFF3A")
]
const GLOW: Array[float] = [0.0, 0.0, 0.6, 1.2, 2.0, 2.0]


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = (load("res://levels/looks/halcyon_interior.tres") as Environment).duplicate()
	environment.environment.fog_enabled = "--distance" in OS.get_cmdline_user_args()
	environment.environment.volumetric_fog_enabled = false
	stage.add_child(environment)
	_floor(stage)
	stage.add_child(_light(Vector3(-3, 4, 4), 1.0, Color("#CDEEE8")))
	stage.add_child(_light(Vector3(3, 3, -2), 0.7, Color("#CDEEE8")))
	stage.add_child(_light(Vector3(2, 2, 3), 0.22, Color("#FF9A42")))
	_build.call_deferred(stage)


func _build(stage: Node3D) -> void:
	var distance: bool = "--distance" in OS.get_cmdline_user_args()
	var rarities: bool = "--rarities" in OS.get_cmdline_user_args() and not distance
	var lineup: bool = ("--lineup" in OS.get_cmdline_user_args() or distance) and not rarities
	var count: int = 6 if rarities else (3 if lineup else 1)
	for index: int in count:
		var frame: String = FRAMES[index] if lineup else "medium"
		var rarity: int = index if rarities else 0
		var player: Node3D = _wear_vest(frame, rarity)
		stage.add_child(player)
		player.position.x = (index - (count - 1) * 0.5) * 1.65
		_label(stage, RARITIES[index] if rarities else frame.capitalize(), player.position.x, TRIMS[rarity])
	_camera(stage, count, distance)
	_capture_mode(lineup, rarities, distance)


func _camera(stage: Node3D, count: int, distance: bool) -> void:
	var camera: Camera3D = Camera3D.new()
	camera.size = 5.65 if count == 6 else (3.5 if count == 3 else 1.5)
	camera.fov = rad_to_deg(2.0 * atan(camera.size / 16.0))
	stage.add_child(camera)
	var target: Vector3 = Vector3(0, 1.05 if count > 1 else 1.30, 0)
	camera.look_at_from_position(target + Vector3(0.15 if count == 1 else 0.0, 0.12, 8), target)
	if distance:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 110.0
		camera.look_at_from_position(target + Vector3(0, 0, 30), target)


func _capture_mode(lineup: bool, rarities: bool, distance: bool) -> void:
	var output: String = "gear_rarities" if rarities else ("gear_frames" if lineup else "gear_medium")
	if distance:
		output = "gear_30m"
	_caption("VEST FRAMES AT 30 M / 110 DEG HORIZONTAL FOV" if distance else output.replace("_", " ").to_upper())
	_capture.call_deferred(output)


func _wear_vest(frame: String, rarity: int) -> Node3D:
	var player: Node3D = (load(PLAYER) as PackedScene).instantiate() as Node3D
	var vest: Node3D = (load("res://assets/models/gear/vest_%s.glb" % frame) as PackedScene).instantiate() as Node3D
	player.add_child(vest)
	var skeleton: Skeleton3D = player.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var shell: MeshInstance3D = vest.find_child("Shell", true, false) as MeshInstance3D
	shell.skeleton = shell.get_path_to(skeleton)
	for node: Node in vest.find_children("*", "BoneAttachment3D", true, false):
		var attachment: BoneAttachment3D = node as BoneAttachment3D
		attachment.use_external_skeleton = true
		attachment.external_skeleton = attachment.get_path_to(skeleton)
	shell.set_instance_shader_parameter(&"trim_color", TRIMS[rarity])
	shell.set_instance_shader_parameter(&"glow_strength", GLOW[rarity])
	shell.set_instance_shader_parameter(&"pulse_seconds", 4.0 if rarity >= 3 else 0.0)
	shell.set_instance_shader_parameter(&"flicker", rarity == 5)
	for cuff: String in ["CuffFP_L", "CuffFP_R"]:
		(vest.find_child(cuff, true, false) as MeshInstance3D).hide()
	return player


func _floor(stage: Node3D) -> void:
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(100, 100)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("#2F393B")
	material.roughness = 0.9
	floor_mesh.mesh = plane
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)


func _light(at: Vector3, energy: float, color: Color) -> DirectionalLight3D:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation = Basis.looking_at(Vector3(0, 1, 0) - at).get_euler()
	light.light_energy = energy
	light.light_color = color
	return light


func _label(stage: Node3D, text: String, x: float, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = 42
	label.pixel_size = 0.0018
	label.modulate = color
	label.position = Vector3(x, -0.14, 0.1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	stage.add_child(label)


func _caption(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = Vector2(48, 36)
	label.add_theme_font_size_override(&"font_size", 26)
	label.modulate = Color("#E8ECE6")
	root.add_child(label)


func _capture(output: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	for _frame: int in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://screenshots/%s.png" % output
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
	quit()

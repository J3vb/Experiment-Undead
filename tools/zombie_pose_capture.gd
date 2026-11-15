## Captures the actual ZombieRig walk poses and black silhouettes for visual review.
## godot --rendering-driver opengl3 --audio-driver Dummy tools/zombie_pose_capture.tscn
extends Node3D

const TYPES: Array[String] = ["shambler", "crawler", "bloater"]
const OUT: String = "res://screenshots/zombie_review"
const SIZE: Vector2i = Vector2i(1280, 720)
const FRAMES: int = 48
const FPS: float = 24.0

var _rigs: Array[ZombieRig] = []
var _stage: Node3D


func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = SIZE
	get_window().content_scale_size = SIZE
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_stage = Node3D.new()
	_stage.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = load("res://levels/looks/halcyon_interior.tres") as Environment
	_stage.add_child(world)
	_stage.add_child(_floor())
	_stage.add_child(_light(Vector3(0, 3.2, 2.5), 2.0))
	_stage.add_child(_light(Vector3(0, 2.0, -2.0), 1.5))
	var camera: Camera3D = Camera3D.new()
	camera.fov = 26.0
	_stage.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.3, 6.3), Vector3(0, 0.85, 0))
	add_child(_stage)
	_run.call_deferred()


func _floor() -> MeshInstance3D:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(12, 8)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("#2F393B")
	material.roughness = 0.72
	plane.material = material
	ground.mesh = plane
	return ground


func _light(at: Vector3, energy: float) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = at
	light.light_energy = energy
	light.light_color = Color("#CDEEE8")
	light.omni_range = 10.0
	return light


func _add_rigs() -> void:
	for index: int in TYPES.size():
		var rig: ZombieRig = ZombieRig.new()
		rig.model = load("res://assets/models/zombies/%s.glb" % TYPES[index]) as PackedScene
		rig.position.x = (index - 1) * 1.65
		rig.rotation.y = PI + 0.3
		_stage.add_child(rig)
		rig.pose_walk(1.5, 0.3, 0.12)
		_rigs.append(rig)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Zombie pose capture needs a display; use xvfb-run with --rendering-driver opengl3")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.path_join("walk")))
	_add_rigs()
	for _frame: int in 12:
		await RenderingServer.frame_post_draw
	_save("zombie_lineup.png")
	for frame: int in FRAMES:
		for rig: ZombieRig in _rigs:
			rig.pose_walk(1.5, 0.3, 1.0 / FPS)
		await RenderingServer.frame_post_draw
		_save("walk/frame_%03d.png" % frame)
	_silhouettes()
	for _frame: int in 3:
		await RenderingServer.frame_post_draw
	_save("zombie_silhouettes.png")
	print("Saved zombie lineup, black silhouettes and %d walk frames to %s" % [FRAMES, OUT])
	get_tree().quit()


func _save(filename: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	if image.save_png(OUT.path_join(filename)) != OK:
		push_error("Cannot save zombie review image: " + filename)
		get_tree().quit(1)


func _silhouettes() -> void:
	var black: StandardMaterial3D = StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	var world: WorldEnvironment = _stage.find_child("*", true, false) as WorldEnvironment
	world.environment = world.environment.duplicate() as Environment
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.WHITE
	world.environment.fog_enabled = false
	world.environment.volumetric_fog_enabled = false
	world.environment.glow_enabled = false
	world.environment.adjustment_enabled = false
	for rig: ZombieRig in _rigs:
		for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = black

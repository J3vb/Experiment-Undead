## Renders the code-built zombies side by side under the interior look and saves
## screenshots/zombie_lineup.png, to compare with the style guide's lineup.
##   xvfb-run -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan -s res://tools/zombie_lineup.gd
extends SceneTree

const LOOK: String = "res://levels/looks/halcyon_interior.tres"
const FLOOR: String = "res://levels/materials/wet_floor.tres"
const ZOMBIES: Array[String] = ["shambler", "crawler", "bloater"]
const OUT: String = "res://screenshots/zombie_lineup.png"
const WARMUP_FRAMES: int = 60


func _initialize() -> void:
	var stage: Node3D = Node3D.new()
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = load(LOOK) as Environment
	stage.add_child(world)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(12, 8)
	plane.material = load(FLOOR) as Material
	ground.mesh = plane
	stage.add_child(ground)
	for i: int in ZOMBIES.size():
		var path: String = "res://assets/models/zombies/%s.glb" % ZOMBIES[i]
		var zombie: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		zombie.position = Vector3((i - 1) * 1.6, 0, 0)
		zombie.rotation.y = -0.5
		stage.add_child(zombie)
	stage.add_child(_light(Vector3(0, 3.2, 1.5), 3.0, true))
	stage.add_child(_light(Vector3(0, 2.5, -2.0), 1.5, false))
	var camera: Camera3D = Camera3D.new()
	camera.fov = 40
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.3, 6.5), Vector3(0, 0.85, 0))
	root.add_child(stage)
	_run.call_deferred()


func _light(at: Vector3, energy: float, shadow: bool) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = at
	light.light_energy = energy
	light.light_color = Color("#CDEEE8")
	light.omni_range = 8.0
	light.shadow_enabled = shadow
	return light


func _run() -> void:
	for _i: int in WARMUP_FRAMES:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	root.get_texture().get_image().save_png(OUT)
	print("saved ", OUT)
	quit()

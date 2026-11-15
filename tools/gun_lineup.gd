## Renders the four code-built guns under the interior look to judge the gun
## finish: screenshots/gun_lineup.png (side view), gun_closeup.png (rifle receiver)
## and gun_shotgun.png (Brenner walnut and receiver).
##   xvfb-run -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 -s res://tools/gun_lineup.gd
extends SceneTree

const LOOK: String = "res://levels/looks/halcyon_interior.tres"
const GUNS: Array[String] = ["rifle_ar", "talon_dmr", "kestrel_smg", "shotgun_brenner"]
const SHOTS: Dictionary[String, Array] = {
	"res://screenshots/gun_lineup.png": [Vector3(-0.15, 0.25, 1.85), Vector3(0.05, -0.33, 0), 34.0],
	"res://screenshots/gun_closeup.png": [Vector3(-0.42, 0.05, 0.42), Vector3(-0.05, -0.02, 0), 30.0],
	"res://screenshots/gun_shotgun.png": [Vector3(-0.05, -0.62, 0.8), Vector3(0.1, -0.76, 0), 40.0],
}
const WARMUP_FRAMES: int = 60


func _initialize() -> void:
	var stage: Node3D = Node3D.new()
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = load(LOOK) as Environment
	stage.add_child(world)
	for i: int in GUNS.size():
		var gun: Node3D = (load("res://assets/models/weapons/%s.glb" % GUNS[i]) as PackedScene).instantiate() as Node3D
		gun.position = Vector3(0, -i * 0.26, 0)
		gun.rotation.y = -PI / 2.0
		stage.add_child(gun)
	stage.add_child(_light(Vector3(-0.6, 0.9, 1.4), 2.2, Color("#CDEEE8")))
	stage.add_child(_light(Vector3(1.4, 0.3, -0.6), 1.4, Color("#E8F6F2")))
	stage.add_child(_light(Vector3(0.2, -1.6, 1.0), 0.6, Color("#9FD8D0")))
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera"
	stage.add_child(camera)
	root.add_child(stage)
	_run.call_deferred(camera)


func _light(at: Vector3, energy: float, color: Color) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = at
	light.light_energy = energy
	light.light_color = color
	light.omni_range = 5.0
	return light


func _run(camera: Camera3D) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	for out: String in SHOTS:
		var shot: Array = SHOTS[out]
		camera.fov = shot[2]
		camera.look_at_from_position(shot[0], shot[1])
		for _i: int in WARMUP_FRAMES:
			await process_frame
		root.get_texture().get_image().save_png(out)
		print("saved ", out)
	quit()

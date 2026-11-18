## Renders the code-built zombies side by side under the interior look and saves
## screenshots/zombie_lineup.png, to compare with the style guide's lineup.
##   xvfb-run -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan -s res://tools/zombie_lineup.gd
extends SceneTree

const STAGE: Script = preload("res://tools/lineup_stage.gd")
const LOOK: String = "res://levels/looks/halcyon_interior.tres"
const FLOOR: String = "res://levels/materials/wet_floor.tres"
const ZOMBIES: Array[String] = ["shambler", "crawler", "bloater"]
const OUT: String = "res://screenshots/zombie_lineup.png"


func _initialize() -> void:
	var stage: Node3D = STAGE.build(LOOK)
	STAGE.floor_plane(stage, FLOOR, Vector2(12, 8))
	for i: int in ZOMBIES.size():
		var path: String = "res://assets/models/zombies/%s.glb" % ZOMBIES[i]
		var zombie: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		zombie.position = Vector3((i - 1) * 1.6, 0, 0)
		zombie.rotation.y = -0.5
		stage.add_child(zombie)
	(STAGE.light(stage, Vector3(0, 3.2, 1.5), 3.0, Color("#CDEEE8"), 8.0) as OmniLight3D).shadow_enabled = true
	STAGE.light(stage, Vector3(0, 2.5, -2.0), 1.5, Color("#CDEEE8"), 8.0)
	var camera: Camera3D = STAGE.camera(stage)
	camera.fov = 40
	root.add_child(stage)
	camera.look_at_from_position(Vector3(0, 1.3, 6.5), Vector3(0, 0.85, 0))
	_run.call_deferred()


func _run() -> void:
	await STAGE.save(self, OUT)
	quit()

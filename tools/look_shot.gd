## Renders the look reference scene and saves screenshots/look_reference.png.
## Needs a GPU or software Vulkan (lavapipe) and a display:
##   xvfb-run -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan -s res://tools/look_shot.gd
extends SceneTree

const SCENE: String = "res://levels/look_reference/halcyon_corridor.tscn"
const OUT: String = "res://screenshots/look_reference.png"
const WARMUP_FRAMES: int = 60


func _initialize() -> void:
	change_scene_to_file(SCENE)
	_run.call_deferred()


func _run() -> void:
	for _i: int in WARMUP_FRAMES:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	root.get_texture().get_image().save_png(OUT)
	print("saved ", OUT)
	quit()

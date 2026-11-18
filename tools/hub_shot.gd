## Renders Lantern Post from the player spawn and from above the street.
## Saves screenshots/hub_street.png, hub_overview.png, hub_gate.png (the Deploy board), hub_lodges.png
## (the west-side lodges), hub_market.png (the stalls), hub_cabins.png (the east side), hub_deploy_gate.png
## (the concrete gate and tunnel), hub_camp.png (fire barrels, benches, crates) and hub_concept.png
## (the camera spot of docs/design/images/lantern_post_concept.jpg):
##   xvfb-run -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan -s res://tools/hub_shot.gd
extends SceneTree

const SCENE: String = "res://levels/lantern_post/lantern_post.tscn"
const WARMUP_FRAMES: int = 90
const EYE_HEIGHT: float = 1.65


func _initialize() -> void:
	var hub: Node3D = (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(hub)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 75.0
	hub.add_child(camera)
	_run.call_deferred(hub, camera)


func _run(hub: Node3D, camera: Camera3D) -> void:
	var spawn: Marker3D = hub.get_node("PlayerSpawn") as Marker3D
	camera.global_position = spawn.global_position + Vector3(5.0, EYE_HEIGHT, 0)
	camera.rotation = Vector3(deg_to_rad(4.0), 0, 0)
	await _shot("res://screenshots/hub_street.png")
	camera.global_position = Vector3(0, 26, 26)
	camera.look_at(Vector3(0, 0, -16))
	await _shot("res://screenshots/hub_overview.png")
	camera.global_position = Vector3(1.2, EYE_HEIGHT, -31.5)
	camera.look_at(Vector3(0, 1.6, -35.5))
	await _shot("res://screenshots/hub_gate.png")
	camera.global_position = Vector3(3.0, 2.0, -14.0)
	camera.look_at(Vector3(-9.0, 4.5, -27.0))
	await _shot("res://screenshots/hub_lodges.png")
	camera.global_position = Vector3(1.5, EYE_HEIGHT, -9.0)
	camera.look_at(Vector3(-5.5, 2.4, -21.0))
	await _shot("res://screenshots/hub_market.png")
	camera.global_position = Vector3(-2.5, 2.2, -4.0)
	camera.look_at(Vector3(8.0, 4.0, -24.0))
	await _shot("res://screenshots/hub_cabins.png")
	camera.global_position = Vector3(-1.5, 2.2, -19.0)
	camera.look_at(Vector3(0.5, 5.0, -38.0))
	await _shot("res://screenshots/hub_deploy_gate.png")
	camera.global_position = Vector3(-3.0, 2.2, 6.0)
	camera.look_at(Vector3(2.0, 5.0, -36.0))
	await _shot("res://screenshots/hub_concept.png")
	camera.global_position = Vector3(-0.5, 1.9, -9.0)
	camera.look_at(Vector3(-2.5, 0.8, -27.0))
	await _shot("res://screenshots/hub_camp.png")
	quit()


func _shot(path: String) -> void:
	for _i: int in WARMUP_FRAMES:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	root.get_texture().get_image().save_png(path)
	var calls: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("saved ", path, " (", calls, " draw calls)")

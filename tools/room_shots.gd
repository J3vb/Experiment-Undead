## Renders one picture per Halcyon Labs room into screenshots/rooms/ for look checks of
## materials and props, and prints the draw calls of each shot. Needs a display:
##   xvfb-run -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 res://tools/room_shots.tscn
extends Node

const MAP: String = "res://levels/halcyon_labs/map.tscn"
const OUT: String = "res://screenshots/rooms/%s.png"
## name, camera position, look-at point (map coordinates, metres).
const SHOTS: Array = [
	["loading_dock", Vector3(24, 1.7, 58), Vector3(44, 1.2, 48)],
	["guard_post", Vector3(12, 1.7, 48), Vector3(20, 1.0, 32)],
	["mess_hall", Vector3(40, 1.7, 44), Vector3(56, 1.5, 32)],
	["main_corridor", Vector3(19, 1.7, 28), Vector3(47, 1.4, 28)],
	["generator_hall", Vector3(10, 1.7, 24), Vector3(26, 1.5, 8)],
	["labs", Vector3(37, 1.7, 25), Vector3(51, 1.0, 11)],
	["coolant_tunnel", Vector3(28.5, 1.7, 12.5), Vector3(36, 1.4, 12.5)],
	["containment_wing", Vector3(62, -1.3, 30), Vector3(74, -2.0, 6)],
	["signs_mess_hall", Vector3(50, 1.7, 42), Vector3(48, 3.6, 30)],
	["signs_vent_ledge", Vector3(50, 1.7, 44), Vector3(58, 2.2, 45)],
	["signs_main_corridor", Vector3(31, 1.7, 29.5), Vector3(31, 1.6, 26)],
	["signs_generator_hall", Vector3(15, 1.7, 20), Vector3(15, 3.6, 6)],
	["signs_labs", Vector3(46, 1.7, 15), Vector3(48, 2.4, 26)],
	["signs_containment_wing", Vector3(68, -1.3, 22), Vector3(68, 0.8, 4)],
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/rooms"))
	var map: Node = (load(MAP) as PackedScene).instantiate()
	add_child(map)
	(map as Level).turn_power_on()
	var camera: Camera3D = Camera3D.new()
	camera.fov = 75.0
	add_child(camera)
	camera.make_current()
	for shot: Array in SHOTS:
		camera.look_at_from_position(shot[1], shot[2])
		for _i: int in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(OUT % shot[0])
		var draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		print("saved %s, draw calls %d" % [shot[0], draws])
	get_tree().quit()

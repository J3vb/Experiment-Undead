## Renders a few Halcyon Labs rooms lit, then in a Blackout, into screenshots/blackout/ for the look check.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan res://tools/blackout_shots.tscn
extends Node

const MAP: String = "res://levels/halcyon_labs/map.tscn"
const OUT: String = "res://screenshots/blackout/%s_%s.png"
const SHOTS: Array = [
	["main_corridor", Vector3(19, 1.7, 28), Vector3(47, 1.4, 28)],
	["mess_hall", Vector3(40, 1.7, 44), Vector3(56, 1.5, 32)],
	["labs", Vector3(37, 1.7, 25), Vector3(51, 1.0, 11)],
	["containment_wing", Vector3(62, -1.3, 30), Vector3(74, -2.0, 6)],
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/blackout"))
	var map: Level = (load(MAP) as PackedScene).instantiate() as Level
	add_child(map)
	map.turn_power_on()
	await get_tree().create_timer(3.0).timeout
	var camera: Camera3D = Camera3D.new()
	camera.fov = 75.0
	add_child(camera)
	camera.make_current()
	await _shoot(camera, "lit")
	Events.blackout_started.emit(6)
	await _shoot(camera, "blackout")
	get_tree().quit()


func _shoot(camera: Camera3D, label: String) -> void:
	for shot: Array in SHOTS:
		camera.look_at_from_position(shot[1], shot[2])
		for _i: int in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(OUT % [shot[0], label])
		print("saved %s %s" % [shot[0], label])

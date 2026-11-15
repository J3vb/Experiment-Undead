# Plays a few seconds of a match and saves screenshots to screenshots/.
# Needs a GPU or software Vulkan (e.g. lavapipe) and a display (xvfb-run):
#   xvfb-run -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan res://tools/screenshot.tscn
extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var session: GameSession = (
		(load("res://systems/game/game_session.tscn") as PackedScene).instantiate() as GameSession
	)
	session.rng_seed = 7
	add_child(session)
	await _seconds(9.0)
	var player: Player = session.get_players()[0]
	var nearest: Zombie = null
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var z: Zombie = n as Zombie
		if (
			z
			and (
				nearest == null
				or (
					z.global_position.distance_to(player.global_position)
					< nearest.global_position.distance_to(player.global_position)
				)
			)
		):
			nearest = z
	if nearest:
		# Stage the shot: put the nearest zombie a few metres in front.
		var front: Vector3 = player.global_position - player.global_basis.z * 6.0
		nearest.global_position = front
		var flat: Vector3 = front
		flat.y = player.global_position.y
		player.look_at(flat)
	await _seconds(0.5)
	_save("01_overview.png")
	player.set_physics_process(false)
	player.weapons.current.ads_progress = 1.0
	await _seconds(0.3)
	player.weapons.current.fire()
	await get_tree().process_frame
	await get_tree().process_frame
	_save("02_ads_fire.png")
	player.weapons.current.ads_progress = 0.0
	player.set_physics_process(true)
	player.rotate_y(PI)
	await _seconds(0.5)
	_save("03_behind.png")
	get_tree().quit()


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _save(file: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/" + file)
	print("saved ", file)

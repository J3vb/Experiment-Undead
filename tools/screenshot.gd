# Plays a few seconds of a match and saves screenshots to screenshots/.
# Needs a GPU or software Vulkan (e.g. lavapipe) and a display (xvfb-run):
#   xvfb-run -s "-screen 0 1600x900x24" godot --path . --script res://tools/screenshot.gd
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var session: GameSession = (load("res://systems/game/game_session.tscn") as PackedScene).instantiate() as GameSession
	session.rng_seed = 7
	root.add_child(session)
	await _seconds(9.0)
	var player: Player = session.get_players()[0]
	var nearest: Zombie = null
	for n: Node in get_nodes_in_group(&"enemies"):
		var z: Zombie = n as Zombie
		if z and (nearest == null or z.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position)):
			nearest = z
	if nearest:
		var flat: Vector3 = nearest.global_position
		flat.y = player.global_position.y
		player.look_at(flat)
	await _seconds(0.5)
	_save("01_overview.png")
	player.weapons.current.aiming = true
	await _seconds(0.4)
	player.weapons.current.fire()
	await process_frame
	await process_frame
	_save("02_ads_fire.png")
	player.weapons.current.aiming = false
	player.rotate_y(PI)
	await _seconds(0.5)
	_save("03_behind.png")
	quit()

func _seconds(t: float) -> void:
	await create_timer(t).timeout

func _save(file: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png("res://screenshots/" + file)
	print("saved ", file)

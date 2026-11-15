## Renders a staged co-op revive HUD for visual review with the real player state presentation.
## Run with a display: godot --path . --rendering-method gl_compatibility res://tests/helpers/coop_hud_shot.tscn
extends Node

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const HUD: PackedScene = preload("res://systems/ui/hud.tscn")
const OUTPUT: String = "res://screenshots/coop_revive_hud.png"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if Net.host(24646, 2) != OK:
		get_tree().quit(1)
		return
	var window: Window = get_tree().root
	window.size = Vector2i(1600, 900)
	var world: Node3D = Node3D.new()
	window.add_child(world)
	var backdrop: WorldEnvironment = WorldEnvironment.new()
	backdrop.environment = Environment.new()
	backdrop.environment.background_mode = Environment.BG_COLOR
	backdrop.environment.background_color = Color("0a1416")
	backdrop.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	backdrop.environment.ambient_light_color = Color("cdeee8")
	backdrop.environment.ambient_light_energy = 0.6
	world.add_child(backdrop)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	world.add_child(light)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color("24363a")
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)
	var hud: Hud = HUD.instantiate() as Hud
	window.add_child(hud)
	hud.set_physics_process(false)
	var player: Player = _make_player(world, "Local", 1)
	var teammate: Player = _make_player(world, "Rook", 2)
	teammate.position = Vector3(0.6, 0.0, -1.2)
	teammate.is_downed = true
	teammate.state_sync._present()
	Events.player_spawned.emit(player)
	player.weapons.give(Content.weapon(&"pistol_service"))
	Events.player_health_changed.emit(player, 75.0, 100.0)
	Events.points_changed.emit(player, 450, 0)
	hud.round_label.text = "4"
	hud.round_label.modulate = Hud.BLOOD_RED
	player.revive.progress = 0.6
	for index: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	window.get_texture().get_image().save_png(OUTPUT)
	Net.leave()
	get_tree().quit()


func _make_player(world: Node3D, player_name: String, peer_id: int) -> Player:
	var player: Player = PLAYER.instantiate() as Player
	player.name = player_name
	player.set_multiplayer_authority(peer_id)
	world.add_child(player)
	player.set_physics_process(false)
	player.state_sync.set_physics_process(false)
	player.revive.set_physics_process(false)
	return player

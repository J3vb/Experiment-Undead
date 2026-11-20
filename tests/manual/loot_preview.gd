## Render personal beams, Pack and overflow results against docs/design/images/.
## DISPLAY=:99 godot --path . --rendering-method gl_compatibility res://tests/manual/loot_preview.tscn
extends Node


func _ready() -> void:
	_render.call_deferred()


func _render() -> void:
	var window: Window = get_tree().root
	window.size = Vector2i(1600, 900)
	var world: Node3D = _world()
	var session: GameSession = GameSession.new()
	session.rng.seed = 73
	session.director = WaveDirector.new()
	session.director.round_number = 17
	var service: LootService = LootService.new()
	service.session = session
	world.add_child(service)
	var hud: Hud = load("res://systems/ui/hud.tscn").instantiate() as Hud
	add_child(hud)
	var player: Player = load("res://systems/player/player.tscn").instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	player.position.z = 5
	hud._player = player
	hud.round_counter.show_round(17)
	player.weapons.give(Content.weapon(&"rifle_ar"))
	service.player = player
	var overlay: PackOverlay = hud.get_node("Root/Pack") as PackOverlay
	overlay.setup(service)
	_items(service)
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png("res://screenshots/loot_beams.png")
	overlay.set_open(true)
	overlay._select(3)
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png("res://screenshots/loot_pack.png")
	overlay.set_open(false)
	var results: ResultsScreen = load("res://systems/ui/results_screen.tscn").instantiate() as ResultsScreen
	add_child(results)
	results.show_results({"round": 17, "loot": service.pack.items, "loot_lost": 2}, 1140)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png("res://screenshots/loot_results.png")
	service.set_physics_process(false)
	session.director.free()
	session.free()
	get_tree().quit()


func _items(service: LootService) -> void:
	for index: int in ItemRoller.RARITIES.size():
		var rarity: StringName = ItemRoller.RARITIES[index]
		var item: Dictionary = (
			ItemRoller.roll_gear(
				service.session.rng, Content.get_item(&"loot", &"vest_light") as GearBaseData, rarity, 17
			)
			if rarity != &"prototype"
			else service._prototype(Content.weapon(&"siphon"))
		)
		service.pack.add(item)
		service.send_drop(1, item, Vector3((index - 2.5) * 0.9, 0, 0))


func _world() -> Node3D:
	var world: Node3D = Node3D.new()
	add_child(world)
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
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("24363a")
	floor_mesh.material_override = material
	world.add_child(floor_mesh)
	return world

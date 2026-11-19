## Lantern Post town scene: a Level that is ready on load, with room for 8 players at the spawn, and a
## Deploy gate that closes the north end.
extends GutTest

const SCENE: String = "res://levels/lantern_post/lantern_post.tscn"
const SQUAD: int = 8
const CAPSULE_RADIUS: float = 0.4
const CAPSULE_HEIGHT: float = 1.8
const CHEST_HEIGHT: float = 1.3
const BOARD_CLEARANCE: float = 1.0
const MAX_SHADOWED_LIGHTS: int = 6
const MAX_LOCAL_LIGHTS: int = 30
const STREET_HALF_WIDTH: float = 4.0
const STALLS: Array[String] = ["Missions", "Trader", "Gunsmith", "Technician"]
const SIGN_TEXTS: Array[String] = [
	"MISSIONS", "TRADER", "Buy / Sell", "GUNSMITH", "Upgrades / Mods", "TECHNICIAN", "Serums / Gear"
]
## A stall's counter front, measured from the stall's middle along its front (+Z) axis.
const COUNTER_FRONT: float = 1.6
const LANE_DEPTH: float = 1.5
const LANE_WIDTH: float = 3.6
## Tunnel pillar faces and how far players may walk in (tools/levels/lantern_post_scene.py TUNNEL_Z, TUNNEL_STOP).
const TUNNEL_MOUTH_Z: float = -37.6
const TUNNEL_WALK_DEPTH: float = 3.0
const TOWN_LOOK: String = "res://levels/looks/lantern_post_night.tres"
const SETTINGS_PATH: String = "user://test_lantern_post_settings.cfg"

var _hub: Level


func before_each() -> void:
	_hub = (load(SCENE) as PackedScene).instantiate() as Level
	add_child_autofree(_hub)


func test_town_is_a_level_ready_without_a_navmesh() -> void:
	assert_not_null(_hub, "root uses the Level script")
	assert_true(_hub.is_navigation_ready, "no zombies, so the town is ready on load")
	assert_not_null(_hub.player_spawn, "players have a spawn marker")


func test_town_has_no_zombie_spawns() -> void:
	assert_eq(_hub.find_children("*", "ZombieSpawnPoint").size(), 0, "no combat in town")
	assert_eq(get_tree().get_nodes_in_group(&"enemy_spawn").size(), 0, "no open spawn points")


func test_eight_players_fit_on_the_spawn_line() -> void:
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = _hub.get_world_3d().direct_space_state
	var spawn: Transform3D = _hub.get_player_spawn()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = Layers.WORLD
	for index: int in SQUAD:
		var origin: Vector3 = spawn.origin + spawn.basis.x * PlayerSpawner.SPAWN_SPACING * index
		var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin + Vector3.UP, origin + Vector3.DOWN * 2.0, Layers.WORLD
		)
		assert_false(space.intersect_ray(down).is_empty(), "floor under spot %d" % index)
		query.transform = Transform3D(Basis.IDENTITY, origin + Vector3.UP * (CAPSULE_HEIGHT * 0.5 + 0.05))
		assert_eq(space.intersect_shape(query).size(), 0, "nothing blocks spot %d" % index)


func test_deploy_board_is_reachable_from_the_spawn() -> void:
	await wait_physics_frames(2)
	var board: Node3D = _hub.get_node("Gate/DeployBoardSpot/DeployBoard") as Node3D
	assert_not_null(board, "the Deploy board stands at its spot")
	var chest: Vector3 = Vector3.UP * CHEST_HEIGHT
	var start: Vector3 = _hub.get_player_spawn().origin + chest
	var target: Vector3 = board.global_position + chest + Vector3.BACK * BOARD_CLEARANCE
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, target, Layers.WORLD)
	var hit: Dictionary = _hub.get_world_3d().direct_space_state.intersect_ray(ray)
	assert_true(hit.is_empty(), "nothing stands between the spawn and the board: %s" % [hit.get("collider")])


func test_lights_stay_in_budget() -> void:
	var lights: Array[Node] = _hub.find_children("*", "Light3D", true, false)
	var shadowed: int = 0
	var local_lights: int = 0
	for node: Node in lights:
		var light: Light3D = node as Light3D
		if light.shadow_enabled:
			shadowed += 1
		if light is OmniLight3D or light is SpotLight3D:
			local_lights += 1
	assert_lte(shadowed, MAX_SHADOWED_LIGHTS, "shadowed lights")
	assert_lte(local_lights, MAX_LOCAL_LIGHTS, "real-time omni and spot lights")


func test_hero_lodges_stand_west_of_the_street_and_block_players() -> void:
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = _hub.get_world_3d().direct_space_state
	for lodge_name: String in ["LodgeLanternPost", "LodgeCommonRoom"]:
		var lodge: Node3D = _hub.get_node_or_null("Lodges/" + lodge_name) as Node3D
		assert_not_null(lodge, lodge_name + " is placed")
		if lodge == null:
			continue
		assert_lt(lodge.global_position.x, -STREET_HALF_WIDTH, lodge_name + " stands west of the street")
		var into: Vector3 = lodge.global_position + Vector3.UP * CHEST_HEIGHT
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(0, CHEST_HEIGHT, into.z), into, Layers.WORLD
		)
		assert_false(space.intersect_ray(ray).is_empty(), lodge_name + " walls stop a player from the street")


func test_every_stall_leaves_a_lane_to_the_street() -> void:
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = _hub.get_world_3d().direct_space_state
	var lane: BoxShape3D = BoxShape3D.new()
	lane.size = Vector3(LANE_WIDTH, CAPSULE_HEIGHT, LANE_DEPTH)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = lane
	query.collision_mask = Layers.WORLD
	for stall_name: String in STALLS:
		var stall: Node3D = _hub.get_node_or_null("Market/%sStall" % stall_name) as Node3D
		assert_not_null(stall, stall_name + " stall is placed")
		if stall == null:
			continue
		var front: Vector3 = stall.global_basis.z.normalized()
		var centre: Vector3 = stall.global_position + front * (COUNTER_FRONT + LANE_DEPTH * 0.5)
		query.transform = Transform3D(stall.global_basis, centre + Vector3.UP * (CAPSULE_HEIGHT * 0.5 + 0.1))
		var hits: Array[Dictionary] = space.intersect_shape(query)
		assert_eq(
			hits.size(),
			0,
			"%s lane is clear: %s" % [stall_name, hits.map(func(h: Dictionary) -> Object: return h.collider)]
		)
		var lane_end: Vector3 = stall.global_position + front * (COUNTER_FRONT + LANE_DEPTH)
		assert_lt(absf(lane_end.x), STREET_HALF_WIDTH, stall_name + " lane reaches the street")


func test_stall_signs_carry_the_stall_names() -> void:
	var texts: Array[String] = []
	for node: Node in _hub.get_node("Market").find_children("*", "Label3D", true, false):
		texts.append((node as Label3D).text)
	for text: String in SIGN_TEXTS:
		assert_has(texts, text, "a stall sign reads " + text)


func test_cabins_stand_east_of_the_street_and_block_players() -> void:
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = _hub.get_world_3d().direct_space_state
	var cabins: Array[Node] = _hub.get_node("Cabins").find_children("Cabin?", "", false, false)
	assert_eq(cabins.size(), 4, "two small and two two-storey cabins")
	for node: Node in cabins:
		var cabin: Node3D = node as Node3D
		assert_gt(cabin.global_position.x, STREET_HALF_WIDTH, cabin.name + " stands east of the street")
		var into: Vector3 = cabin.global_position + Vector3.UP * CHEST_HEIGHT
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(0, CHEST_HEIGHT, into.z), into, Layers.WORLD
		)
		assert_false(space.intersect_ray(ray).is_empty(), cabin.name + " walls stop a player from the street")


func test_deploy_tunnel_is_closed_three_metres_in() -> void:
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = _hub.get_world_3d().direct_space_state
	var board: Vector3 = (_hub.get_node("Gate/DeployBoardSpot") as Node3D).global_position
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, CHEST_HEIGHT, board.z), Vector3(0, CHEST_HEIGHT, board.z - 20.0), Layers.WORLD
	)
	var hit: Dictionary = space.intersect_ray(ray)
	assert_false(hit.is_empty(), "something closes the tunnel")
	if hit.is_empty():
		return
	var depth: float = TUNNEL_MOUTH_Z - (hit.position as Vector3).z
	assert_almost_eq(depth, TUNNEL_WALK_DEPTH, 0.3, "players walk 3 m into the tunnel, then stop")


func test_gate_wall_closes_the_north_end() -> void:
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = _hub.get_world_3d().direct_space_state
	for x: float in [-24.0, -17.0, -9.0, -4.5, 4.5, 9.0, 17.0, 24.0]:
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(x, CHEST_HEIGHT, -33.0), Vector3(x, CHEST_HEIGHT, -48.0), Layers.WORLD
		)
		var hit: Dictionary = space.intersect_ray(ray)
		assert_false(hit.is_empty(), "the gate stops a player at x %.1f" % x)


func test_concrete_wall_closes_the_west_east_and_south_sides() -> void:
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = _hub.get_world_3d().direct_space_state
	var rays: Array[Array] = []
	for z: float in [-34.0, -20.0, -4.0, 12.0]:
		rays.append([Vector3(18.0, CHEST_HEIGHT, z), Vector3(32.0, CHEST_HEIGHT, z)])
		rays.append([Vector3(-18.0, CHEST_HEIGHT, z), Vector3(-32.0, CHEST_HEIGHT, z)])
	for x: float in [-22.0, -8.0, 0.0, 8.0, 22.0]:
		rays.append([Vector3(x, CHEST_HEIGHT, 8.0), Vector3(x, CHEST_HEIGHT, 22.0)])
	for ray_ends: Array in rays:
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			ray_ends[0] as Vector3, ray_ends[1] as Vector3, Layers.WORLD
		)
		assert_false(space.intersect_ray(ray).is_empty(), "the town wall stops a player at %s" % str(ray_ends[1]))
	var sections: int = (
		_hub
		. get_node("Walls")
		. find_children("*", "", false, false)
		. filter(func(n: Node) -> bool: return not n is StaticBody3D)
		. size()
	)
	assert_eq(sections, 21, "21 gate_wall sections ring the west, east and south sides")


func test_no_pine_stands_in_the_deploy_tunnel() -> void:
	for pine: Node in _hub.get_node("Pines").get_children():
		var at: Vector3 = (pine as Node3D).position
		assert_false(absf(at.x) < 9.0 and at.z > -55.0, "%s keeps out of the tunnel" % pine.name)


func test_gate_has_a_deploy_sign_and_banners() -> void:
	var texts: Array[String] = []
	for node: Node in _hub.get_node("Gate").find_children("*", "Label3D", true, false):
		texts.append((node as Label3D).text)
	assert_has(texts, "DEPLOY", "the tunnel reads DEPLOY")
	assert_eq(_hub.get_node("Gate").find_children("Banner?", "", false, false).size(), 4, "4 banners on the wall")
	assert_not_null(_hub.get_node_or_null("Gate/CommonRoomBanner"), "and one by the Common Room")


func test_watchtower_spotlight_sweeps() -> void:
	var sweep: Node3D = _hub.get_node_or_null("Cabins/WatchtowerSweep") as Node3D
	assert_not_null(sweep, "the watchtower has a sweep pivot")
	if sweep == null:
		return
	assert_eq(sweep.find_children("*", "SpotLight3D", false, false).size(), 1, "one beam")
	var player: AnimationPlayer = sweep.get_node("Sweep") as AnimationPlayer
	assert_eq(player.autoplay, &"sweep", "the sweep starts on its own")
	assert_eq(player.get_animation(&"sweep").loop_mode, Animation.LOOP_LINEAR, "and loops")
	var start: float = sweep.rotation.y
	await wait_seconds(0.5)
	assert_ne(sweep.rotation.y, start, "the beam moves")


func test_fire_barrels_burn_and_flicker() -> void:
	var fires: Array[Node] = _hub.get_node("Props").find_children("FireBarrel?", "", false, false)
	assert_eq(fires.size(), 4, "four fire barrels")
	for fire: Node in fires:
		assert_eq(fire.find_children("*", "GPUParticles3D", true, false).size(), 1, fire.name + " has flames")
		var light: OmniLight3D = fire.get_node("Light") as OmniLight3D
		assert_false(light.shadow_enabled, fire.name + " light casts no shadow (shadow budget)")
		var flicker: AnimationPlayer = fire.get_node("Flicker") as AnimationPlayer
		assert_eq(flicker.autoplay, &"flicker", fire.name + " flickers on its own")
		assert_eq(flicker.get_animation(&"flicker").loop_mode, Animation.LOOP_LINEAR, fire.name + " keeps flickering")
	var light: OmniLight3D = (fires[0] as Node).get_node("Light") as OmniLight3D
	var start: float = light.light_energy
	await wait_seconds(0.3)
	assert_ne(light.light_energy, start, "the fire light changes")


func test_camp_props_block_players() -> void:
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = _hub.get_world_3d().direct_space_state
	for path: String in ["Props/FireBarrel0", "Props/Bench0", "Props/Crate0", "Props/Firewood0", "Props/FenlightBase0"]:
		var prop: Node3D = _hub.get_node(path) as Node3D
		var top: Vector3 = prop.global_position + Vector3.UP * 3.0
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			top, prop.global_position + Vector3.UP * 0.05, Layers.WORLD
		)
		assert_false(space.intersect_ray(ray).is_empty(), path + " has a collider")


func test_fenlight_crates_carry_their_stencil() -> void:
	var texts: Array[String] = []
	for node: Node in _hub.get_node("Props").find_children("FenlightStencil*", "Label3D", false, false):
		texts.append((node as Label3D).text)
	assert_eq(texts.size(), 2, "two Fenlight sample crates")
	assert_has(texts, "FENLIGHT\nSAMPLES", "the crates read FENLIGHT SAMPLES")


func test_graphics_preset_reaches_the_town_look() -> void:
	var world: EnvironmentQuality = _hub.get_node("WorldEnvironment") as EnvironmentQuality
	assert_not_null(world, "the town look follows the graphics settings")
	if world == null:
		return
	assert_eq(world.look.resource_path, TOWN_LOOK, "the scene points at the shared town look")
	var old_path: String = Settings.config_path
	var old_values: Dictionary = Settings._values.duplicate(true)
	Settings.config_path = SETTINGS_PATH
	Settings.set_value(&"graphics", &"preset", Graphics.Preset.LOW)
	assert_false(world.environment.ssao_enabled, "Low turns ambient occlusion off in town")
	assert_false(world.environment.volumetric_fog_enabled, "Low turns volumetric fog off in town")
	assert_true(world.look.ssao_enabled and world.look.volumetric_fog_enabled, "the shared look is unchanged")
	Settings._values = old_values
	Settings._apply_all()
	Settings.config_path = old_path
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))

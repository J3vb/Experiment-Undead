## Lantern Post town scene: a Level that is ready on load, with room for 8 players at the spawn.
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
const COUNTER_FRONT: float = 1.45
const LANE_DEPTH: float = 1.5
const LANE_WIDTH: float = 3.6

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

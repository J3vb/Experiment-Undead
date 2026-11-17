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

## Checks the Halcyon Labs map against the maps doc: the blockout matches its
## layout.json, every area is reachable once its doors are open, closed doors
## cut the navmesh, spawn points follow the placement rules, light budget holds.
extends GutTest

const MAP: String = "res://levels/halcyon_labs/map.tscn"
const BLOCKOUT: String = "res://levels/halcyon_labs/blockout.tscn"
const LOOK: String = "res://levels/looks/halcyon_interior.tres"
const BUILDER: String = "res://tools/blockout_builder.gd"
const AREAS: Array[StringName] = [
	&"loading_dock",
	&"guard_post",
	&"mess_hall",
	&"main_corridor",
	&"generator_hall",
	&"labs",
	&"containment_wing",
	&"coolant_tunnel",
]
const MIN_SPAWN_DISTANCE: float = 12.0
## A point on the vent ledge above the Mess Hall, and one in the Containment Wing.
const VENT_LEDGE: Vector3 = Vector3(60, 1.4, 45.5)
const CONTAINMENT: Vector3 = Vector3(70, -3, 20)
## Props keep this far (m) from openings, interactables and spawn points.
const PROP_CLEARANCE: float = 1.5
const MAX_SHADOWED_PER_ROOM: int = 2
const LIGHTMAP_FILES: Array[String] = ["res://levels/halcyon_labs/map.exr", "res://levels/halcyon_labs/map.lmbake"]
const MAX_LIGHTMAP_BYTES: int = 15 * 1024 * 1024


func _spawn_points(level: Node) -> Array[ZombieSpawnPoint]:
	var out: Array[ZombieSpawnPoint] = []
	for node: Node in level.find_children("*", "Marker3D"):
		if node is ZombieSpawnPoint:
			out.append(node as ZombieSpawnPoint)
	return out


func _load_map(open_doors: bool) -> Level:
	var level: Level = (load(MAP) as PackedScene).instantiate() as Level
	if open_doors:
		level.get_node("NavigationRegion3D/Doors").free()
	add_child_autofree(level)
	await wait_until(func() -> bool: return level.is_navigation_ready, 15.0, "navmesh baked")
	return level


func _path_end_gap(level: Level, from: Vector3, to: Vector3) -> float:
	var map: RID = level.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	return INF if path.is_empty() else path[path.size() - 1].distance_to(to)


func test_blockout_is_up_to_date_with_layout() -> void:
	var builder: GDScript = load(BUILDER) as GDScript
	var built: Node3D = builder.build(builder.load_layout("halcyon_labs"))
	var saved: Node = (load(BLOCKOUT) as PackedScene).instantiate()
	assert_eq(_node_paths(saved), _node_paths(built), "rerun tools/blockout_builder.gd after editing layout.json")
	built.free()
	saved.free()


func _node_paths(root: Node) -> Array[String]:
	var out: Array[String] = []
	for node: Node in root.find_children("*", "", true, false):
		out.append(str(root.get_path_to(node)))
	out.sort()
	return out


func test_map_uses_the_shared_look() -> void:
	var level: Node = (load(MAP) as PackedScene).instantiate()
	add_child_autofree(level)
	var world: EnvironmentQuality = level.get_node("WorldEnvironment") as EnvironmentQuality
	assert_not_null(world, "graphics settings can turn its effects off")
	assert_eq(world.look.resource_path, LOOK, "the scene points at the shared look; only the run-time copy changes")
	assert_not_null(level.get_node_or_null("FilmPost"), "film grain and vignette")


func test_each_room_keeps_the_shadow_light_budget() -> void:
	var level: Node = (load(MAP) as PackedScene).instantiate()
	add_child_autofree(level)
	var rooms: Node = level.get_node("NavigationRegion3D/Blockout")
	for room: Node in rooms.get_children():
		var shadowed: int = 0
		for node: Node in room.find_children("*", "Light3D"):
			if (node as Light3D).shadow_enabled:
				shadowed += 1
		assert_lte(shadowed, MAX_SHADOWED_PER_ROOM, "%s shadowed lights" % room.name)


func test_spawn_points_follow_the_rules() -> void:
	var level: Level = (load(MAP) as PackedScene).instantiate() as Level
	add_child_autofree(level)
	var points: Array[ZombieSpawnPoint] = _spawn_points(level)
	var coop: Array[ZombieSpawnPoint] = points.filter(func(p: ZombieSpawnPoint) -> bool: return p.min_players > 1)
	assert_between(points.size() - coop.size(), 21, 28, "21 to 28 spawn points for any squad")
	assert_eq(coop.size(), 4, "co-op points: 2 truck gaps, Mess Hall vent, Containment Wing vent")
	for point: ZombieSpawnPoint in coop:
		assert_eq(point.min_players, 3, "%s opens at 3 players" % point.name)
	var start: Vector3 = level.get_player_spawn().origin
	for area: StringName in AREAS:
		var count: int = points.filter(func(p: ZombieSpawnPoint) -> bool: return p.area == area).size()
		assert_gte(count, 1 if area == &"coolant_tunnel" else 2, "spawn points in %s" % area)
	for point: ZombieSpawnPoint in points:
		assert_has(AREAS, point.area, "%s has a known area" % point.name)
		assert_gte(
			point.global_position.distance_to(start), MIN_SPAWN_DISTANCE, "%s is far from the start" % point.name
		)


func test_only_start_area_spawn_points_are_active() -> void:
	var level: Level = (load(MAP) as PackedScene).instantiate() as Level
	add_child_autofree(level)
	assert_eq(level.open_areas, [&"loading_dock"] as Array[StringName])
	var active: Array[Node] = get_tree().get_nodes_in_group(&"enemy_spawn")
	assert_eq(active.size(), 6, "the four Loading Dock windows and the two co-op truck gaps")
	for node: Node in active:
		assert_eq((node as ZombieSpawnPoint).area, &"loading_dock")
	level.open_area(&"guard_post")
	assert_eq(get_tree().get_nodes_in_group(&"enemy_spawn").size(), 8, "Guard Post windows join")


func test_every_spawn_point_reaches_the_start_with_doors_open() -> void:
	var level: Level = await _load_map(true)
	var start: Vector3 = level.get_player_spawn().origin
	for point: ZombieSpawnPoint in _spawn_points(level):
		var gap: float = _path_end_gap(level, point.global_position, start)
		assert_lt(gap, 1.0, "%s has a path to the start" % point.name)


func test_closed_doors_cut_the_navmesh() -> void:
	var level: Level = await _load_map(false)
	var start: Vector3 = level.get_player_spawn().origin
	for point: ZombieSpawnPoint in _spawn_points(level):
		var gap: float = _path_end_gap(level, point.global_position, start)
		if point.area == &"loading_dock":
			assert_lt(gap, 1.0, "%s reaches the start" % point.name)
		else:
			assert_gt(gap, 1.0, "%s is sealed off by a closed door" % point.name)


func test_kestrel_replaces_its_wall_placeholder() -> void:
	var level: Level = (load(MAP) as PackedScene).instantiate() as Level
	add_child_autofree(level)
	var wall: WallBuy = level.find_child("WallBuyKestrel", true, false) as WallBuy
	assert_not_null(wall)
	if wall:
		assert_eq(wall.weapon.id, &"kestrel_smg")
		assert_eq(wall.position, Vector3(10.25, 1.4, 32))
		assert_eq(wall.basis, Basis.IDENTITY, "same facing as the placeholder")
		assert_eq((wall.get_node("Label") as Label3D).text, "Kestrel SMG 1000")
	assert_eq(get_tree().get_nodes_in_group(&"wall_buy_spot").size(), 0, "no wall-gun placeholders remain")


func test_talon_replaces_its_wall_placeholder() -> void:
	var level: Level = (load(MAP) as PackedScene).instantiate() as Level
	add_child_autofree(level)
	var wall: WallBuy = level.find_child("WallBuyTalon", true, false) as WallBuy
	assert_not_null(wall)
	if wall:
		assert_eq(wall.weapon.id, &"talon_dmr")
		assert_eq(wall.position, Vector3(8.25, 1.4, 20))
		assert_eq(wall.basis, Basis.IDENTITY, "same facing as the placeholder")
		assert_eq((wall.get_node("Label") as Label3D).text, "Talon DMR 1500")


func test_map_has_baked_lightmaps_under_the_size_budget() -> void:
	var level: Node = (load(MAP) as PackedScene).instantiate()
	add_child_autofree(level)
	var lightmap: LightmapGI = level.get_node_or_null("LightmapGI") as LightmapGI
	assert_not_null(lightmap, "map has a LightmapGI")
	if lightmap:
		assert_not_null(lightmap.light_data, "lightmaps are baked")
	var total: int = 0
	for path: String in LIGHTMAP_FILES:
		assert_true(FileAccess.file_exists(path), "%s is committed" % path)
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file:
			total += file.get_length()
	assert_lt(total, MAX_LIGHTMAP_BYTES, "lightmaps stay small enough for plain git")


func test_things_that_move_or_vanish_are_not_baked() -> void:
	var level: Node = (load(MAP) as PackedScene).instantiate()
	add_child_autofree(level)
	var blocks: Array[Node] = level.get_node("NavigationRegion3D/Doors").find_children("Blocker", "StaticBody3D")
	blocks.append_array(level.find_children("Board", "StaticBody3D"))
	blocks.append(level.get_node("NavigationRegion3D/Machines/SpecimenVault/Body"))
	assert_eq(blocks.size(), 12 + 6 + 1, "9 doors, 2 vent grates, the freezer, 6 wall-buys, the vault")
	for node: Node in blocks:
		assert_false((node as Block).baked, "%s is not baked" % level.get_path_to(node))
	var planks: Array[Node] = level.get_node("Barriers").find_children("Plank*", "MeshInstance3D", true, false)
	assert_eq(planks.size(), 16 * 6, "16 barriers of 6 planks")
	for node: Node in planks:
		var gi: int = (node as GeometryInstance3D).gi_mode
		assert_ne(gi, GeometryInstance3D.GI_MODE_STATIC, "%s is not baked" % level.get_path_to(node))
	assert_false((level.get_node("VentStep/Ramp") as Block).baked, "the vent step comes and goes")
	var wreckage: Node = level.get_node("TruckWreckage")
	assert_eq(wreckage.find_children("*", "CollisionObject3D", true, false).size(), 0, "wreckage is decoration only")
	for node: Node in wreckage.find_children("*", "MeshInstance3D", true, false):
		assert_ne((node as GeometryInstance3D).gi_mode, GeometryInstance3D.GI_MODE_STATIC, "wreckage vanishes in co-op")


func test_ceiling_lights_stay_real_time() -> void:
	var level: Node = (load(MAP) as PackedScene).instantiate()
	add_child_autofree(level)
	var fixtures: Array[Node] = level.find_children("Fixture", "SpotLight3D", true, false)
	assert_gt(fixtures.size(), 0, "map has ceiling lights")
	for node: Node in fixtures:
		assert_eq((node as Light3D).light_bake_mode, Light3D.BAKE_DYNAMIC, "fixtures bake only their bounce")
	assert_eq(level.find_children("Spill*", "Light3D", true, false).size(), 0, "bounce comes from the bake")


func test_coachman_wall_buy_matches_the_layout_and_sells_for_900() -> void:
	var level: Node = (load(MAP) as PackedScene).instantiate()
	add_child_autofree(level)
	var wall: WallBuy = level.find_child("WallBuyCoachman", true, false) as WallBuy
	assert_not_null(wall, "Halcyon has its signature wall gun")
	if wall == null:
		return
	assert_eq(wall.weapon, Content.weapon(&"coachman_2b"))
	assert_eq(wall.weapon.cost, 900)
	assert_eq(wall.position, Vector3(38.25, 1.4, 38), "Mess Hall west wall, clear of doors and windows")
	assert_eq((wall.get_node("Label") as Label3D).text, "Coachman 900")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/halcyon_labs/layout.json"))
	var placement: Dictionary = layout["wall_buys"][0]
	assert_eq(placement["id"], "coachman_2b")
	assert_eq(placement["area"], "mess_hall", "outside the Loading Dock")
	assert_eq(placement["position"], [38.25, 1.4, 38.0])
	assert_eq(int(placement["cost"]), wall.weapon.cost)


func test_zombie_sized_body_walks_up_the_containment_ramp_into_the_labs() -> void:
	var level: Level = await _load_map(true)
	var body: CharacterBody3D = CharacterBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	level.add_child(body)
	body.global_position = Vector3(55.0, -1.0, 18.0)
	for i: int in 120:
		body.velocity = Vector3(-3.0, body.velocity.y - 0.3, 0.0)
		body.move_and_slide()
		await wait_physics_frames(1)
	assert_lt(body.global_position.x, 51.0, "no lip where the ramp meets the Labs opening")


func test_props_sit_in_their_rooms_clear_of_doors_machines_and_spawns() -> void:
	var layout: Dictionary = (load(BUILDER) as GDScript).load_layout("halcyon_labs")
	var rooms: Dictionary = {}
	for room: Dictionary in layout["rooms"]:
		rooms[room["id"]] = room["rect"]
	var keep_clear: Array[Vector3] = []
	for opening: Dictionary in layout["openings"]:
		keep_clear.append(Vector3(opening["at"][0], opening["at"][1], float(opening["width"]) * 0.5))
	var level: Level = (load(MAP) as PackedScene).instantiate() as Level
	add_child_autofree(level)
	for node: Node in level.find_children("*", "Node3D"):
		if node is Interactable or node is ZombieSpawnPoint or node.is_in_group(&"vault_spot"):
			var at: Vector3 = (node as Node3D).global_position
			keep_clear.append(Vector3(at.x, at.z, 0.0))
	var start: Vector3 = level.get_player_spawn().origin
	keep_clear.append(Vector3(start.x, start.z, 0.0))
	for prop: Dictionary in layout["props"]:
		var b: Array = prop["box"]
		var footprint: Rect2 = Rect2(b[0] - b[3] * 0.5, b[2] - b[5] * 0.5, b[3], b[5])
		var r: Array = rooms[prop["room"]]
		var inside: Rect2 = Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).grow(-0.2)
		assert_true(inside.encloses(footprint), "%s sits inside %s" % [prop["id"], prop["room"]])
		for point: Vector3 in keep_clear:
			var gap: float = _rect_distance(footprint, Vector2(point.x, point.y)) - point.z
			assert_gte(gap, PROP_CLEARANCE, "%s is clear of %s" % [prop["id"], Vector2(point.x, point.y)])


func _rect_distance(rect: Rect2, point: Vector2) -> float:
	var nearest: Vector2 = point.clamp(rect.position, rect.end)
	return nearest.distance_to(point)


func test_mess_hall_tables_make_a_loop() -> void:
	var level: Level = await _load_map(true)
	var map: RID = level.get_world_3d().navigation_map
	var across: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(48, 0, 33), Vector3(48, 0, 43), true)
	assert_lt(across[across.size() - 1].distance_to(Vector3(48, 0, 43)), 1.0, "a way round the tables")
	assert_gt(_length(across), 14.0, "the tables block the straight line, so the path goes round an end")
	assert_lt(_path_end_gap(level, Vector3(40.5, 0, 38), Vector3(55.5, 0, 38)), 1.0, "a lane between the tables")


func _length(path: PackedVector3Array) -> float:
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func _load_map_keeping(kept_doors: Array[String]) -> Level:
	var level: Level = (load(MAP) as PackedScene).instantiate() as Level
	for door: Node in level.get_node("NavigationRegion3D/Doors").get_children():
		if not kept_doors.has(String(door.name)):
			door.free()
	add_child_autofree(level)
	await wait_until(func() -> bool: return level.is_navigation_ready, 15.0, "navmesh baked")
	return level


func test_vent_duct_never_skips_the_containment_door() -> void:
	var level: Level = await _load_map_keeping(["ContainmentDoor", "VentGrateContainment"])
	assert_gt(_path_end_gap(level, VENT_LEDGE, CONTAINMENT), 1.0, "Mess Hall open, Containment shut: no way in")


func test_vent_duct_walks_down_into_containment_once_both_are_open() -> void:
	var level: Level = await _load_map_keeping([])
	assert_lt(_path_end_gap(level, VENT_LEDGE, CONTAINMENT), 1.0, "ledge to Containment Wing down the duct")
	var map: RID = level.get_world_3d().navigation_map
	var up: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(55, 0, 44), VENT_LEDGE, true)
	assert_gt(_length(up), 40.0, "no walking up the 1.4 m drop: only the long way round through the duct")


func test_vent_ledge_is_out_of_jump_reach_but_the_step_reaches_it() -> void:
	var player: Player = (load("res://systems/player/player.tscn") as PackedScene).instantiate() as Player
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * player.gravity_multiplier
	var jump: float = player.jump_velocity * player.jump_velocity / (2.0 * gravity)
	player.free()
	assert_lt(jump, VENT_LEDGE.y - 0.2, "solo players cannot jump back up")
	var level: Node = (load(MAP) as PackedScene).instantiate()
	add_child_autofree(level)
	var ramp: Block = level.get_node("VentStep/Ramp") as Block
	var top_end: Vector3 = ramp.global_transform * Vector3(ramp.size.x * 0.5, ramp.size.y * 0.5, 0)
	assert_gte(top_end.y, VENT_LEDGE.y, "the step reaches the ledge")
	assert_lt(rad_to_deg(ramp.global_basis.x.angle_to(Vector3.RIGHT)), 45.0, "the step is walkable")

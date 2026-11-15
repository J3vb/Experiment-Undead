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
	var world: WorldEnvironment = level.get_node("WorldEnvironment") as WorldEnvironment
	assert_eq(world.environment.resource_path, LOOK, "shared interior look, not a copy")
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
	assert_between(points.size(), 21, 28, "21 to 28 spawn points")
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
	assert_eq(active.size(), 4, "the four Loading Dock windows")
	for node: Node in active:
		assert_eq((node as ZombieSpawnPoint).area, &"loading_dock")
	level.open_area(&"guard_post")
	assert_eq(get_tree().get_nodes_in_group(&"enemy_spawn").size(), 6, "Guard Post windows join")


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
	assert_eq(blocks.size(), 9 + 5 + 1, "9 doors, 5 wall-buys, the vault")
	for node: Node in blocks:
		assert_false((node as Block).baked, "%s is not baked" % level.get_path_to(node))
	var planks: Array[Node] = level.get_node("Barriers").find_children("Plank*", "MeshInstance3D", true, false)
	assert_eq(planks.size(), 16 * 6, "16 barriers of 6 planks")
	for node: Node in planks:
		var gi: int = (node as GeometryInstance3D).gi_mode
		assert_ne(gi, GeometryInstance3D.GI_MODE_STATIC, "%s is not baked" % level.get_path_to(node))


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

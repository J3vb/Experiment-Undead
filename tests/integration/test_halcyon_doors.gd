## Plays Halcyon Labs headless: buying doors costs points and opens areas,
## doors to the same area open together, power doors wait for the power
## switch, wall-buys (rifle and Brenner Trench) sell guns and ammo, and with
## everything open every spawn point can walk to the start.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const DOORS_TOTAL: int = 7000

var session: GameSession
var player: Player
var level: Level


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	session.rng_seed = 99
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	player = session.get_players()[0]
	level = session.level


func after_each() -> void:
	get_tree().paused = false


func _door(door_name: String) -> Door:
	return level.get_node("NavigationRegion3D/Doors/" + door_name) as Door


func _doors() -> Array[Door]:
	var out: Array[Door] = []
	for node: Node in get_tree().get_nodes_in_group(&"doors"):
		out.append(node as Door)
	return out


func test_buying_a_door_opens_its_area() -> void:
	player.wallet.set_points(5000)
	var door: Door = _door("GuardPostDoor")
	door.interact(player)
	assert_eq(player.wallet.points, 4250, "door cost 750")
	assert_true(door.is_open)
	assert_true(door.is_queued_for_deletion(), "door removed")
	assert_null(door.get_node_or_null("Blocker"), "blocker gone at once, so the rebake does not see it")
	assert_has(level.open_areas, &"guard_post")
	assert_eq(get_tree().get_nodes_in_group(&"enemy_spawn").size(), 6, "Guard Post windows join")


func test_door_stays_shut_without_points() -> void:
	player.wallet.set_points(100)
	var door: Door = _door("GuardPostDoor")
	door.interact(player)
	assert_false(door.is_open)
	assert_eq(player.wallet.points, 100)


func test_doors_to_the_same_area_open_together() -> void:
	player.wallet.set_points(5000)
	var other: Door = _door("CorridorDoorMessHall")
	_door("CorridorDoorGuardPost").interact(player)
	assert_true(other.is_open, "the Mess Hall side opens too")
	assert_eq(player.wallet.points, 4000, "paid once")


func test_power_doors_need_the_power_switch() -> void:
	player.wallet.set_points(5000)
	var labs: Door = _door("LabsDebris")
	var tunnel: Door = _door("TunnelWestShutter")
	var tunnel_east: Door = _door("TunnelEastShutter")
	labs.interact(player)
	assert_false(labs.is_open, "no power yet")
	assert_eq(labs.get_prompt(player), "Needs power")
	assert_eq(player.wallet.points, 5000)
	var switch: PowerSwitch = level.find_child("PowerSwitch", true, false) as PowerSwitch
	switch.interact(player)
	assert_true(level.power_on)
	assert_true(tunnel.is_open, "Coolant Tunnel opens free with power")
	assert_true(tunnel_east.is_open)
	labs.interact(player)
	assert_true(labs.is_open)
	assert_eq(player.wallet.points, 3500)


func test_door_costs_match_the_maps_doc() -> void:
	var by_area: Dictionary = {}
	for door: Door in _doors():
		by_area[door.opens_area] = door.cost
	var total: int = 0
	for cost: int in by_area.values():
		total += cost
	assert_eq(total, DOORS_TOTAL, "cost to open everything")
	assert_eq(by_area.size(), 7, "every area but the start has a door")


func test_machines_are_placed() -> void:
	assert_eq(get_tree().get_nodes_in_group(&"med_dispenser").size(), 8, "8 Med Dispensers")
	assert_eq(get_tree().get_nodes_in_group(&"vault_spot").size(), 6, "6 Specimen Vault spots")
	assert_eq(get_tree().get_nodes_in_group(&"reforger").size(), 1, "1 Reforger")
	assert_eq(get_tree().get_nodes_in_group(&"exfil").size(), 1, "1 exfil point")
	assert_not_null(level.find_child("PowerSwitch", true, false), "1 power switch")
	var wall_buys: int = level.find_children("*", "Area3D").filter(func(n: Node) -> bool: return n is WallBuy).size()
	assert_eq(wall_buys, 5, "four shared wall guns and the signature Coachman")
	assert_eq(get_tree().get_nodes_in_group(&"wall_buy_spot").size(), 0, "no wall-gun placeholders remain")


func test_wall_buy_sells_ammo_and_guns() -> void:
	var wall_buy: WallBuy = level.find_child("WallBuyRifle", true, false) as WallBuy
	player.wallet.set_points(5000)
	var rifle: Weapon = player.weapons.weapons[1]
	rifle.instance.ammo_reserve = 0
	wall_buy.interact(player)
	assert_eq(rifle.instance.ammo_reserve, rifle.data.max_reserve, "ammo refilled")
	assert_eq(player.wallet.points, 4400, "ammo costs half")
	wall_buy.weapon = rifle.data.duplicate() as WeaponData
	wall_buy.interact(player)
	assert_eq(player.weapons.current.data, wall_buy.weapon, "new gun in hand")
	assert_eq(player.wallet.points, 3200, "gun costs its WeaponData cost")


func test_brenner_wall_buy_sells_the_shotgun() -> void:
	var wall_buy: WallBuy = level.find_child("WallBuyBrennerTrench", true, false) as WallBuy
	assert_not_null(wall_buy, "Brenner Trench is a real wall-buy")
	if wall_buy == null:
		return
	player.global_position = Vector3(44.6, 0.0, 52.0)
	player.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	await wait_physics_frames(3)
	assert_eq(player.focus, wall_buy as Interactable, "board under the crosshair")
	player.wallet.set_points(1000)
	wall_buy.interact(player)
	assert_eq(player.weapons.current.data.id, &"brenner_trench", "shotgun in hand")
	assert_eq(player.weapons.weapons.size(), 2, "two slots: it replaced the gun in hand")
	assert_eq(player.wallet.points, 250, "costs 750")


func test_player_sees_the_door_prompt_from_near_and_far() -> void:
	# 22.65 is pressed against the blocker: the camera must stay outside the door's area.
	for x: float in [22.65, 23.5]:
		player.global_position = Vector3(x, 0.0, 48.0)
		player.rotation = Vector3(0.0, PI * 0.5, 0.0)
		await wait_physics_frames(3)
		assert_eq(player.focus, _door("GuardPostDoor") as Interactable, "door under the crosshair at x = %.2f" % x)
		if player.focus:
			assert_string_contains(player.focus.get_prompt(player), "750")


func test_everything_open_lets_every_spawn_point_reach_the_start() -> void:
	level.turn_power_on()
	for door: Door in _doors():
		door.open()
	assert_eq(get_tree().get_nodes_in_group(&"enemy_spawn").size(), 21, "every spawn point is active")
	var map: RID = level.get_world_3d().navigation_map
	var start: Vector3 = level.get_player_spawn().origin
	var far: Vector3 = Vector3(75.0, -3.0, 8.0)
	await wait_until(func() -> bool: return _reaches(map, far, start), 20.0, "rebaked navmesh synced")
	for node: Node in get_tree().get_nodes_in_group(&"enemy_spawn"):
		var point: Node3D = node as Node3D
		assert_true(_reaches(map, point.global_position, start), "%s reaches the start" % point.name)


func _reaches(map: RID, from: Vector3, to: Vector3) -> bool:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) < 1.0


func test_coachman_wall_buy_sells_the_signature_shotgun() -> void:
	var wall: WallBuy = level.find_child("WallBuyCoachman", true, false) as WallBuy
	assert_not_null(wall)
	if wall == null:
		return
	player.wallet.set_points(900)
	wall.interact(player)
	assert_eq(player.weapons.current.data.id, &"coachman_2b")
	assert_eq(player.weapons.current.instance.ammo_in_mag, 2)
	assert_eq(player.wallet.points, 0, "charges the roster price once")

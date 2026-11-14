## Buys, fires, refills and Reforges the Kestrel in a real Halcyon Labs session.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession
var player: Player
var wall: WallBuy


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.rng_seed = 23
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	player = session.get_players()[0]
	wall = session.level.find_child("WallBuyKestrel", true, false) as WallBuy
	player.wallet.set_points(10000)


func test_buy_fire_and_refill_at_the_wall() -> void:
	player.global_position = Vector3(11.4, 0.0, 32.0)
	player.rotation = Vector3(0.0, PI * 0.5, 0.0)
	await wait_physics_frames(3)
	assert_eq(player.focus, wall as Interactable, "wall under the crosshair")
	assert_string_contains(wall.get_prompt(player), "1000")
	wall.interact(player)
	var gun: Weapon = player.weapons.current
	assert_eq(gun.data.id, &"kestrel_smg")
	assert_eq(player.wallet.points, 9000)
	assert_eq(player.weapons.weapons.size(), 2)
	assert_eq(gun.instance.ammo_in_mag, 30)
	assert_eq(gun.instance.ammo_reserve, 180)
	gun.trigger_held = true
	for tick: int in range(60):
		gun.tick(1.0 / 60.0)
	gun.trigger_held = false
	assert_eq(gun.instance.ammo_in_mag, 15, "850 rpm: 15 shots in the first second")
	assert_eq(gun.instance.ammo_reserve, 180)
	assert_eq(player.wallet.points, 9000, "firing at a wall costs no points")
	assert_true(gun.start_reload())
	gun.tick(gun.data.reload_time)
	assert_eq(gun.instance.ammo_in_mag, 30)
	assert_eq(gun.instance.ammo_reserve, 165)
	assert_string_contains(wall.get_prompt(player), "500")
	wall.interact(player)
	assert_eq(gun.instance.ammo_reserve, 180)
	assert_eq(player.wallet.points, 8500, "wall ammo costs half the gun price")


func test_reforge_and_buy_upgraded_ammo() -> void:
	wall.interact(player)
	session.level.turn_power_on()
	var reforger: Reforger = session.level.find_child("Reforger", true, false) as Reforger
	reforger.interact(player)
	var gun: Weapon = player.weapons.current
	assert_eq(gun.data.id, &"kestrel_smg_reforged")
	assert_eq(gun.instance.ammo_in_mag, 45)
	assert_eq(gun.instance.ammo_reserve, 360)
	assert_eq(player.wallet.points, 4000)
	gun.instance.ammo_reserve = 0
	wall.interact(player)
	assert_eq(gun.instance.ammo_reserve, 360)
	assert_eq(player.weapons.weapons.size(), 2)
	assert_eq(player.wallet.points, 0, "Reforged wall ammo uses the existing 4000 price")

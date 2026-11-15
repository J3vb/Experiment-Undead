## The Reforger on Halcyon Labs: needs power, turns the gun in hand into its
## Tier I version, then sells ammo refills. Wall-buys know the Reforged gun.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession
var player: Player
var level: Level
var reforger: Reforger


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	session.rng_seed = 11
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	player = session.get_players()[0]
	level = session.level
	reforger = get_tree().get_first_node_in_group(&"reforger") as Reforger
	player.wallet.set_points(20000)


func test_needs_power() -> void:
	assert_eq(reforger.get_prompt(player), "Needs power")
	var before: WeaponData = player.weapons.current.data
	reforger.interact(player)
	assert_eq(player.weapons.current.data, before)
	assert_eq(player.wallet.points, 20000)


func test_reforges_the_gun_in_hand_in_its_slot() -> void:
	level.turn_power_on()
	var base: WeaponData = player.weapons.current.data
	var slot: int = player.weapons.weapons.find(player.weapons.current)
	var count: int = player.weapons.weapons.size()
	assert_string_contains(reforger.get_prompt(player), "5000")
	reforger.interact(player)
	var gun: Weapon = player.weapons.current
	assert_eq(gun.data, base.upgraded, "upgraded gun in hand")
	assert_eq(player.weapons.weapons.find(gun), slot, "same slot")
	assert_eq(player.weapons.weapons.size(), count, "no extra gun")
	assert_eq(gun.instance.ammo_in_mag, gun.data.magazine_size, "full magazine")
	assert_eq(player.wallet.points, 15000)


func test_reforged_gun_buys_refills() -> void:
	level.turn_power_on()
	reforger.interact(player)
	var gun: Weapon = player.weapons.current
	assert_eq(reforger.get_prompt(player), "", "full ammo: nothing to buy")
	gun.instance.ammo_reserve = 0
	assert_string_contains(reforger.get_prompt(player), "2500")
	reforger.interact(player)
	assert_eq(gun.instance.ammo_reserve, gun.data.max_reserve)
	assert_eq(player.wallet.points, 12500)


func test_wall_buy_sells_ammo_for_the_reforged_gun() -> void:
	level.turn_power_on()
	var wall_buy: WallBuy = level.find_child("WallBuyRifle", true, false) as WallBuy
	player.weapons.equip(player.weapons.weapons.find(_rifle()))
	reforger.interact(player)
	var gun: Weapon = player.weapons.current
	gun.instance.ammo_reserve = 0
	var count: int = player.weapons.weapons.size()
	wall_buy.interact(player)
	assert_eq(player.weapons.weapons.size(), count, "no base rifle bought next to the Reforged one")
	assert_eq(gun.instance.ammo_reserve, gun.data.max_reserve)
	assert_eq(player.wallet.points, 20000 - 5000 - 4000)


func _rifle() -> Weapon:
	for gun: Weapon in player.weapons.weapons:
		if gun.data.id == &"rifle_ar":
			return gun
	return null

## Buys and fires the Talon on Halcyon Labs, checks round-one damage,
## Reforging and the map's real Specimen Vault pool.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession
var player: Player
var wall: WallBuy


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.rng_seed = 1234
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	session.director.stop()
	player = session.get_players()[0]
	wall = session.level.find_child("WallBuyTalon", true, false) as WallBuy
	player.wallet.set_points(10000)


func _buy() -> Weapon:
	wall.interact(player)
	return player.weapons.current


func test_wall_buy_is_focused_and_sells_gun_and_ammo() -> void:
	assert_not_null(wall, "Talon is a real WallBuy")
	player.global_position = Vector3(9.6, 0, 20)
	player.rotation = Vector3(0, PI * 0.5, 0)
	await wait_physics_frames(3)
	assert_eq(player.focus, wall as Interactable)
	assert_string_contains(wall.get_prompt(player), "1500")
	var weapon: Weapon = _buy()
	assert_eq(weapon.data.id, &"talon_dmr")
	assert_eq(player.wallet.points, 8500)
	assert_eq(weapon.instance.ammo_in_mag, 15)
	assert_eq(weapon.instance.ammo_reserve, 90)
	weapon.instance.ammo_reserve = 0
	wall.interact(player)
	assert_eq(weapon.instance.ammo_reserve, 90)
	assert_eq(player.wallet.points, 7750, "ammo costs half")


func _walker() -> Zombie:
	var zombie: Zombie = session.spawner.spawn(Content.enemy(&"zombie_walker"), 1, session.wave_rules)
	zombie.set_physics_process(false)
	zombie.set_process(false)
	zombie.visual.position.y = 0.0
	zombie.global_position = Vector3(34, 0, 52)
	zombie.rotation = Vector3.ZERO
	return zombie


func test_one_ads_headshot_kills_a_fresh_round_one_walker_but_body_does_not() -> void:
	var weapon: Weapon = _buy()
	player.global_position = Vector3(34, 0, 56)
	player.set_physics_process(false)
	weapon.aiming = true
	weapon.ads_progress = 1.0
	var zombie: Zombie = _walker()
	await wait_physics_frames(2)
	var expected_health: float = Content.enemy(&"zombie_walker").max_health
	expected_health *= session.wave_rules.get_health_multiplier(1)
	assert_almost_eq(zombie.health.current, expected_health, 0.001, "health from enemy and wave resources")
	watch_signals(weapon)
	player.camera.look_at(zombie.global_position + Vector3(0, 0.9, 0))
	weapon.fire()
	assert_almost_eq(zombie.health.current, expected_health - 68.0 * 0.57, 0.001, "one body hit")
	assert_false(zombie.health.is_dead, "body hit does not kill")
	zombie.free()
	zombie = _walker()
	await wait_physics_frames(2)
	weapon.tick(0.25)
	player.camera.look_at(zombie.head_zone.global_position)
	weapon.fire()
	assert_true(zombie.health.is_dead, "one headshot kills a fresh Walker")
	assert_signal_emitted_with_parameters(weapon, "hit_landed", [true, true])
	assert_eq(weapon.instance.ammo_in_mag, 13, "one round per shot")


func test_reforger_upgrades_talon_and_wall_refills_it() -> void:
	_buy()
	session.level.turn_power_on()
	var reforger: Reforger = session.level.find_child("Reforger", true, false) as Reforger
	reforger.interact(player)
	var weapon: Weapon = player.weapons.current
	assert_eq(weapon.data.id, &"talon_dmr_reforged")
	assert_eq(weapon.instance.ammo_in_mag, 22, "15 x 1.5 truncates like the Tier I rule")
	assert_eq(weapon.instance.ammo_reserve, 180)
	weapon.instance.ammo_reserve = 0
	player.wallet.set_points(4000)
	wall.interact(player)
	assert_eq(weapon.instance.ammo_reserve, 180)
	assert_eq(player.wallet.points, 0)


func test_map_vault_can_offer_and_give_talon() -> void:
	var vault: SpecimenVault = session.level.find_child("SpecimenVault", true, false) as SpecimenVault
	assert_has(vault.pool, Content.weapon(&"talon_dmr"), "real map pool contains Talon")
	session.level.turn_power_on()
	var offered: bool = false
	for attempt: int in 30:
		vault.interact(player)
		vault._physics_process(SpecimenVault.ROLL_TIME + 0.01)
		if vault.offer == Content.weapon(&"talon_dmr"):
			offered = true
			vault.interact(player)
			break
		vault._physics_process(SpecimenVault.OFFER_TIME + 0.01)
	assert_true(offered, "seeded rolls offer Talon")
	assert_eq(player.weapons.current.data.id, &"talon_dmr")

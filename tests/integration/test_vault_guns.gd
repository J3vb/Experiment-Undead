## Fires each of the five Vault guns in a real Halcyon Labs session: they hurt a
## round-one Walker, the Mako fires three-round bursts and the Corvid one-shots.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const VAULT_GUNS: Array[StringName] = [&"hollis_44", &"mako_pdw", &"atlas_auto", &"halberd_lmg", &"corvid_338"]

var session: GameSession
var player: Player


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	session.rng_seed = 77
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	session.director.stop()
	player = session.get_players()[0]
	player.weapons.max_slots = 8
	player.global_position = Vector3(34, 0, 55)
	player.set_physics_process(false)


func _take(id: StringName) -> Weapon:
	player.weapons.give(Content.weapon(id))
	player.weapons.equip(player.weapons.weapons.size() - 1)
	var weapon: Weapon = player.weapons.current
	weapon.aiming = true
	weapon.ads_progress = 1.0
	return weapon


func _walker() -> Zombie:
	var zombie: Zombie = session.spawner.spawn(Content.enemy(&"zombie_walker"), 1, session.wave_rules)
	zombie.set_physics_process(false)
	zombie.set_process(false)
	zombie.visual.position.y = 0.0
	zombie.global_position = Vector3(34, 0, 52)
	zombie.rotation = Vector3.ZERO
	return zombie


func test_every_vault_gun_hits_a_walker() -> void:
	for id: StringName in VAULT_GUNS:
		var weapon: Weapon = _take(id)
		var zombie: Zombie = _walker()
		await wait_physics_frames(2)
		var start: float = zombie.health.current
		player.camera.look_at(zombie.global_position + Vector3(0, 0.9, 0))
		weapon.fire()
		var dealt: float = start - zombie.health.current
		assert_gte(dealt, minf(weapon.data.damage, start) - 0.001, String(id) + " lands at least one full hit")
		assert_eq(weapon.instance.ammo_in_mag, weapon.data.magazine_size - 1, String(id) + " one round per shot")
		zombie.free()


func test_corvid_body_shot_kills_a_round_one_walker() -> void:
	_take(&"corvid_338")
	var zombie: Zombie = _walker()
	await wait_physics_frames(2)
	player.camera.look_at(zombie.global_position + Vector3(0, 0.9, 0))
	player.weapons.current.fire()
	assert_true(zombie.health.is_dead, "600 x 0.57 is far over a fresh Walker")


func test_mako_fires_three_round_bursts() -> void:
	var weapon: Weapon = _take(&"mako_pdw")
	weapon.trigger_held = true
	for tick: int in range(12):
		weapon.tick(1.0 / 60.0)
	assert_eq(weapon.instance.ammo_in_mag, 37, "one press, one burst of three")
	for tick: int in range(30):
		weapon.tick(1.0 / 60.0)
	assert_eq(weapon.instance.ammo_in_mag, 37, "holding the trigger does not start another burst")
	weapon.trigger_held = false
	weapon.tick(1.0 / 60.0)
	weapon.trigger_held = true
	for tick: int in range(12):
		weapon.tick(1.0 / 60.0)
	assert_eq(weapon.instance.ammo_in_mag, 34, "a new press fires the next burst")


func test_vault_can_offer_each_new_gun() -> void:
	var vault: SpecimenVault = session.level.find_child("SpecimenVault", true, false) as SpecimenVault
	for id: StringName in VAULT_GUNS:
		assert_has(vault.pool, Content.weapon(id), String(id) + " is in the Halcyon Labs Vault pool")

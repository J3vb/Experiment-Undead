## Server rule skills: Last Stand, Undying's self-revive charge and Bargain Hunter's Vault price.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.second_wind_time = 0.05


func _rank(ranks: Dictionary[StringName, int]) -> void:
	player.skill_ranks = ranks
	player.equip_gear([])


func _hit(amount: float) -> void:
	player.take_damage(DamageInfo.create(amount, null))


func test_last_stand_leaves_one_health_then_ignores_hits_for_two_seconds() -> void:
	_rank({&"last_stand": 1})
	_hit(500.0)
	assert_eq(player.health.current, 1.0)
	assert_false(player.health.is_dead)
	_hit(50.0)
	assert_eq(player.health.current, 1.0, "immune")
	player.revive._physics_process(2.1)
	_hit(500.0)
	assert_true(player.health.is_dead, "once per round")


func test_last_stand_comes_back_next_round() -> void:
	_rank({&"last_stand": 1})
	_hit(500.0)
	player.revive._physics_process(2.1)
	Events.round_started.emit(2, 6)
	_hit(500.0)
	assert_eq(player.health.current, 1.0)


func test_without_last_stand_a_killing_blow_kills() -> void:
	_hit(500.0)
	assert_true(player.health.is_dead)


func test_undying_self_revives_once_per_run_and_costs_every_serum() -> void:
	_rank({&"undying": 1})
	var serum: SerumData = SerumData.new()
	serum.id = &"ironhide"
	player.serums.append(serum)
	_hit(500.0)
	assert_true(player.is_downed)
	assert_true(player.can_self_revive(), "the squad is not out")
	await wait_until(func() -> bool: return not player.is_downed, 2.0, "back up")
	assert_eq(player.health.current, player.health.max_health)
	assert_true(player.serums.is_empty())
	assert_false(player.revive.has_undying_charge())
	_hit(500.0)
	await wait_seconds(0.2)
	assert_true(player.is_dead, "no second charge")


func test_second_wind_is_used_before_the_undying_charge() -> void:
	_rank({&"undying": 1})
	var serum: SerumData = SerumData.new()
	serum.id = &"second_wind"
	player.serums.append(serum)
	_hit(500.0)
	await wait_until(func() -> bool: return not player.is_downed, 2.0, "back up")
	assert_true(player.revive.has_undying_charge(), "the charge is kept")


func test_bargain_hunter_vault_price() -> void:
	var vault: SpecimenVault = SpecimenVault.new()
	autofree(vault)
	assert_eq(vault.price(player), 950)
	_rank({&"bargain_hunter": 1})
	assert_eq(vault.price(player), 750)


func _rifle_with(in_mag: int) -> Weapon:
	var weapon: Weapon = player.weapons.give(Content.weapon(&"rifle_ar"))
	weapon.instance.ammo_in_mag = in_mag
	return weapon


func test_dead_center_refunds_a_round_on_a_headshot_kill_only() -> void:
	_rank({&"dead_center": 1})
	var rifle: Weapon = _rifle_with(10)
	Events.hit_confirmed.emit(player, true, true)
	assert_eq(rifle.instance.ammo_in_mag, 11)
	Events.hit_confirmed.emit(player, true, false)
	Events.hit_confirmed.emit(player, false, true)
	assert_eq(rifle.instance.ammo_in_mag, 11, "body kills and headshot hits refund nothing")


func test_dead_center_never_overfills_and_needs_the_skill() -> void:
	var rifle: Weapon = _rifle_with(10)
	Events.hit_confirmed.emit(player, true, true)
	assert_eq(rifle.instance.ammo_in_mag, 10, "no skill")
	_rank({&"dead_center": 1})
	rifle.instance.ammo_in_mag = rifle.data.magazine_size
	Events.hit_confirmed.emit(player, true, true)
	assert_eq(rifle.instance.ammo_in_mag, rifle.data.magazine_size)


func test_dead_center_skips_the_server_copy_of_a_client() -> void:
	_rank({&"dead_center": 1})
	var rifle: Weapon = _rifle_with(10)
	player.set_multiplayer_authority(7, false)
	Events.hit_confirmed.emit(player, true, true)
	assert_eq(rifle.instance.ammo_in_mag, 10)

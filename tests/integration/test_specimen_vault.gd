## The Specimen Vault on Halcyon Labs: needs power, a roll costs 950 and
## offers a gun the player does not hold, the offer runs out, and after its
## last roll the Vault refunds and moves to another vault_spot.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession
var player: Player
var level: Level
var vault: SpecimenVault


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	session.rng_seed = 5
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	player = session.get_players()[0]
	level = session.level
	vault = get_tree().get_first_node_in_group(&"specimen_vault") as SpecimenVault
	player.wallet.set_points(10000)


func _finish_roll() -> void:
	vault._physics_process(SpecimenVault.ROLL_TIME + 0.01)


func test_one_vault_on_the_first_spot() -> void:
	assert_eq(get_tree().get_nodes_in_group(&"specimen_vault").size(), 1, "one Vault at a time")
	assert_eq(vault.spot.name, &"VaultSpotMessHall", "starts in the Mess Hall")
	assert_almost_eq(vault.global_position.distance_to(vault.spot.global_position), 0.0, 0.01)


func test_needs_power() -> void:
	assert_eq(vault.get_prompt(player), "Needs power")
	vault.interact(player)
	assert_eq(vault.state, SpecimenVault.State.IDLE)
	assert_eq(player.wallet.points, 10000)
	assert_false(vault.get_node("Glow").visible, "dark before power")
	level.turn_power_on()
	assert_true(vault.get_node("Glow").visible, "lights up with power")
	assert_string_contains(vault.get_prompt(player), "950")


func test_player_sees_the_vault_prompt() -> void:
	level.turn_power_on()
	player.global_position = Vector3(50.0, 0.0, 44.1)
	player.rotation = Vector3(0.0, PI, 0.0)
	await wait_physics_frames(3)
	assert_eq(player.focus, vault as Interactable, "Vault under the crosshair")


func test_roll_offers_a_gun_the_player_does_not_hold() -> void:
	level.turn_power_on()
	vault.interact(player)
	assert_eq(player.wallet.points, 9050, "a roll costs 950")
	assert_eq(vault.state, SpecimenVault.State.ROLLING)
	assert_eq(vault.get_prompt(player), "", "nothing to press while rolling")
	_finish_roll()
	assert_eq(vault.state, SpecimenVault.State.OFFERING)
	assert_has(vault.pool, vault.offer, "offers a gun from the map pool")
	assert_ne(vault.offer.id, &"rifle_ar", "never the gun the player holds")
	var offered: WeaponData = vault.offer
	assert_string_contains(vault.get_prompt(player), "Take " + offered.display_name)
	vault.interact(player)
	assert_eq(player.weapons.current.data, offered, "gun in hand")
	assert_eq(vault.state, SpecimenVault.State.IDLE)


func test_offer_runs_out() -> void:
	level.turn_power_on()
	vault.interact(player)
	_finish_roll()
	vault._physics_process(SpecimenVault.OFFER_TIME + 0.01)
	assert_eq(vault.state, SpecimenVault.State.IDLE)
	assert_eq(player.weapons.current.data.id, &"rifle_ar", "offer left in the Vault")


## Holds each pool gun except `skip`, using Reforged where available.
func _hold_pool_except(skip: StringName) -> void:
	player.weapons.max_slots = vault.pool.size() + 1
	for gun: WeaponData in vault.pool:
		if gun.id != skip and gun.id != &"rifle_ar":
			player.weapons.give(gun.upgraded if gun.upgraded else gun)
	player.weapons.equip(0)


func test_nothing_to_roll_when_the_player_holds_the_whole_pool() -> void:
	level.turn_power_on()
	assert_eq(vault.pool.size(), 20, "Halcyon pool preserves all existing guns, both double-barrels and Bastion")
	_hold_pool_except(&"")
	assert_eq(vault.get_prompt(player), "")
	vault.interact(player)
	assert_eq(vault.state, SpecimenVault.State.IDLE)


func test_last_roll_refunds_and_moves_the_vault() -> void:
	level.turn_power_on()
	var start: Node3D = vault.spot
	var rolls: int = 0
	while vault.spot == start and rolls < 20:
		vault.interact(player)
		_finish_roll()
		if vault.state == SpecimenVault.State.OFFERING:
			vault._physics_process(SpecimenVault.OFFER_TIME + 0.01)
		rolls += 1
	assert_ne(vault.spot, start, "Vault moved")
	assert_between(rolls, vault.min_rolls_before_move, vault.max_rolls_before_move, "moves after 4 to 8 rolls")
	assert_eq(player.wallet.points, 10000 - 950 * (rolls - 1), "the moving roll is refunded")
	assert_true(vault.spot.is_in_group(&"vault_spot"))
	var gap: float = vault.global_position.distance_to(vault.spot.global_position)
	assert_almost_eq(gap, 0.0, 0.01, "Vault sits on its new spot")


func test_vault_can_offer_the_kestrel_from_the_map_pool() -> void:
	_hold_pool_except(&"kestrel_smg")
	level.turn_power_on()
	vault.interact(player)
	_finish_roll()
	assert_eq(vault.state, SpecimenVault.State.OFFERING)
	assert_not_null(vault.offer)
	if vault.offer:
		assert_eq(vault.offer.id, &"kestrel_smg", "all other pool guns held: only Kestrel remains")
	vault.interact(player)
	assert_eq(player.weapons.current.data.id, &"kestrel_smg")
	assert_eq(player.weapons.current.instance.ammo_in_mag, 30)
	assert_eq(player.wallet.points, 9050)


func test_bargain_hunter_pays_750_and_the_moving_roll_refunds_750() -> void:
	level.turn_power_on()
	player.skill_ranks = {&"bargain_hunter": 1}
	player.equip_gear([])
	assert_eq(vault.get_prompt(player), "Roll the Specimen Vault [F]  750")
	var start: Node3D = vault.spot
	var rolls: int = 0
	while vault.spot == start and rolls < 20:
		vault.interact(player)
		_finish_roll()
		if vault.state == SpecimenVault.State.OFFERING:
			vault._physics_process(SpecimenVault.OFFER_TIME + 0.01)
		rolls += 1
	assert_eq(player.wallet.points, 10000 - 750 * (rolls - 1), "refund is the 750 paid, not 950")

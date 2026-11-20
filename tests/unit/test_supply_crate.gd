## The Supply Crate in solo: the power-up leaves a crate where it was picked up, opening it
## rolls a free gun, the opener takes it, and an unopened crate is gone after 25 s.
extends GutTest

const CRATE: PowerUpData = preload("res://content/power_ups/supply_crate.tres")
const PISTOL: WeaponData = preload("res://content/weapons/pistol_service.tres")

var session: GameSession
var drops: PowerUpDrops
var player: Player


func before_each() -> void:
	session = CoopSide.make(self, "Solo", [&"interactions"])
	drops = session.power_up_drops
	player = CoopSide.add_player(session, 1)
	player.spawn(session, [PISTOL])


func after_each() -> void:
	CoopSide.close(session)


func _crate() -> SupplyCrate:
	drops._spawn(CRATE, Vector3(4, 0, 2)).collect(player)
	for node: Node in session.level.get_children():
		if node is SupplyCrate:
			var crate: SupplyCrate = node as SupplyCrate
			crate.pool = [Content.weapon(&"hollis_44"), Content.weapon(&"coachman_2b")]
			return crate
	return null


func test_supply_crate_is_rare_and_instant() -> void:
	assert_eq(CRATE.effect, PowerUpData.Effect.SUPPLY_CRATE)
	assert_almost_eq(CRATE.deck_chance, 0.333, 0.001)
	assert_eq(CRATE.duration, 0.0)


func test_pickup_leaves_a_crate_on_the_spot() -> void:
	var crate: SupplyCrate = _crate()
	assert_not_null(crate)
	assert_almost_eq(crate.position, Vector3(4, 0, 2), Vector3.ONE * 0.01)
	assert_eq(crate.get_prompt(player), "Open the Supply Crate [F]")
	assert_true(crate.net_state().is_empty(), "nothing to sync before it is opened")


func test_open_roll_and_take_a_free_gun() -> void:
	var crate: SupplyCrate = _crate()
	player.wallet.set_points(0)
	crate.interact(player)
	assert_eq(crate.state, SupplyCrate.State.ROLLING)
	assert_eq(player.wallet.points, 0, "free")
	crate._physics_process(SupplyCrate.ROLL_TIME + 0.1)
	assert_eq(crate.state, SupplyCrate.State.OFFERING)
	var offer: WeaponData = crate.offer
	assert_has(crate.pool, offer)
	crate.interact(player)
	assert_true(player.weapons.weapons.any(func(w: Weapon) -> bool: return w.data == offer), "the gun is given")
	assert_true(crate.is_queued_for_deletion(), "used up")


func test_an_unopened_crate_vanishes_after_25_seconds() -> void:
	var crate: SupplyCrate = _crate()
	crate._physics_process(24.0)
	assert_false(crate.is_queued_for_deletion())
	crate._physics_process(1.5)
	assert_true(crate.is_queued_for_deletion())


func test_the_clock_stops_once_opened_and_an_untaken_offer_ends() -> void:
	var crate: SupplyCrate = _crate()
	crate._physics_process(24.0)
	crate.interact(player)
	crate._physics_process(SupplyCrate.ROLL_TIME + 0.1)
	assert_false(crate.is_queued_for_deletion(), "rolling does not age it")
	crate._physics_process(SupplyCrate.OFFER_TIME - 1.0)
	assert_false(crate.is_queued_for_deletion(), "offering does not age it")
	crate._physics_process(1.5)
	assert_true(crate.is_queued_for_deletion(), "the offer ran out")

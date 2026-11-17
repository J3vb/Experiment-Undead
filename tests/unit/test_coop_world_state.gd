## Two ENet peers: barriers, the Specimen Vault and the exfil hatch work from
## a client, every peer sees the same state, and a late joiner gets it all.
extends "res://tests/unit/coop_interaction_fixture.gd"


func _barrier(session: GameSession) -> Barrier:
	return target(session, "Barrier") as Barrier


func _vault(session: GameSession) -> SpecimenVault:
	return target(session, "Vault") as SpecimenVault


func _hatch(session: GameSession) -> ExfilHatch:
	return target(session, "Hatch") as ExfilHatch


func _power_on() -> void:
	server.level.turn_power_on()
	await wait_until(func() -> bool: return client.level.power_on, 3.0, "power reached the client")


## Rolls the Vault from the client and skips the roll time on the server.
func _roll() -> void:
	on_server().wallet.set_points(5000)
	await press("Vault")
	await wait_until(func() -> bool: return _vault(client).state == SpecimenVault.State.ROLLING, 3.0, "rolling")
	_vault(server)._timer = 0.0


func _late_joiner() -> void:
	late = make_side("InteractLate")
	add_player(late, client_id)
	await join(late)


func test_client_repairs_a_plank_and_server_tears_reach_the_client() -> void:
	_barrier(server).tear_plank()
	_barrier(server).tear_plank()
	await wait_until(func() -> bool: return _barrier(client).planks == 4, 3.0, "tears reached the client")
	assert_true((_barrier(client).get_node("TearSound") as AudioStreamPlayer3D).playing)
	await press("Barrier")
	await wait_until(func() -> bool: return _barrier(client).planks == 5, 3.0, "repair reached the client")
	assert_eq(_barrier(server).planks, 5)
	assert_eq(on_server().wallet.points, 10, "repair paid")
	assert_true((_barrier(client).get_node("RepairSound") as AudioStreamPlayer3D).playing)


func test_repair_pay_stops_at_the_round_cap() -> void:
	server.economy._repair_points[on_server()] = 495
	_barrier(server).tear_plank()
	await press("Barrier")
	await wait_until(func() -> bool: return _barrier(client).planks == 6, 3.0, "repaired")
	assert_eq(on_server().wallet.points, 5, "only up to the cap")


func test_client_rolls_and_takes_the_vault_offer() -> void:
	await _power_on()
	await _roll()
	await wait_until(func() -> bool: return _vault(client).state == SpecimenVault.State.OFFERING, 3.0, "offer shown")
	assert_eq(on_server().wallet.points, 5000 - _vault(server).cost)
	var offer: WeaponData = _vault(server).offer
	assert_eq(_vault(client).offer, offer)
	assert_eq(_vault(client).buyer_id, client_id)
	assert_ne(_vault(client).get_prompt(on_client()), "", "the buyer sees Take")
	server.interactions._time += 1.0
	await press("Vault")
	await wait_until(func() -> bool: return on_client().weapons.weapons.size() == 1, 3.0, "gun granted")
	assert_eq(on_client().weapons.current.data, offer)
	await wait_until(func() -> bool: return _vault(client).state == SpecimenVault.State.IDLE, 3.0, "closed")


func test_another_client_cannot_take_the_offer() -> void:
	await _power_on()
	await _roll()
	await wait_until(func() -> bool: return _vault(client).state == SpecimenVault.State.OFFERING, 3.0, "offer shown")
	await _late_joiner()
	var late_id: int = late.multiplayer.get_unique_id()
	add_player(server, late_id)
	add_player(client, late_id)
	var other: Player = add_player(late, late_id)
	await wait_until(func() -> bool: return _vault(late).state == SpecimenVault.State.OFFERING, 3.0, "late sees offer")
	assert_eq(_vault(late).get_prompt(other), "", "not the buyer")
	late.interactions.request(other, _vault(late))
	await wait_physics_frames(6)
	assert_eq(_vault(server).state, SpecimenVault.State.OFFERING, "offer still waits for its buyer")
	assert_eq(other.weapons.weapons.size(), 0)


func test_vault_move_refunds_the_buyer_and_moves_on_both_peers() -> void:
	await _power_on()
	_vault(server).rolls_left = 1
	await _roll()
	await wait_until(func() -> bool: return _vault(client).spot.name == &"SpotFar", 3.0, "moved on the client")
	assert_eq(_vault(server).spot.name, &"SpotFar")
	assert_eq(on_server().wallet.points, 5000, "roll refunded")
	assert_true(_vault(client).global_position.is_equal_approx(Vector3(20, 1, 20)))
	assert_eq(_vault(client).state, SpecimenVault.State.IDLE)


func test_exfil_opens_on_round_10_and_client_sees_it() -> void:
	watch_signals(Events)
	Events.round_started.emit(10, 10)
	await wait_until(func() -> bool: return _hatch(client).is_open, 3.0, "open reached the client")
	assert_true(_hatch(server).is_open)
	assert_true((_hatch(client).get_node("Glow") as Node3D).visible)
	assert_signal_emit_count(Events, "exfil_opened", 2, "once on the server, once on the client")


func test_client_calls_exfil_and_the_hold_counts_like_the_server() -> void:
	Events.round_started.emit(10, 10)
	await wait_until(func() -> bool: return _hatch(client).is_open, 3.0, "open")
	await press("Hatch")
	await wait_until(func() -> bool: return _hatch(client).is_counting, 3.0, "counting on the client")
	assert_true(_hatch(server).is_holding)
	await wait_seconds(1.0)
	assert_lt(_hatch(server).hold_left, ExfilHatch.HOLD_TIME - 0.5, "the server's hold runs")
	assert_almost_eq(_hatch(client).hold_left, _hatch(server).hold_left, 0.5)
	on_client().global_position = Vector3(30, 0, 0)
	await wait_until(func() -> bool: return not _hatch(client).is_counting, 3.0, "stopped on the client")
	var paused: float = _hatch(client).hold_left
	await wait_seconds(0.5)
	assert_eq(_hatch(client).hold_left, paused, "no countdown while nobody is in the zone")
	assert_almost_eq(paused, _hatch(server).hold_left, 0.5)


func test_late_joiner_gets_planks_vault_and_exfil_hold() -> void:
	await _power_on()
	_barrier(server).tear_plank()
	await _roll()
	await wait_until(func() -> bool: return _vault(server).state == SpecimenVault.State.OFFERING, 3.0, "offering")
	Events.round_started.emit(10, 10)
	server.interactions._time += 1.0
	_hatch(server).interact(on_server())
	await wait_seconds(0.5)
	await _late_joiner()
	await wait_until(func() -> bool: return _hatch(late).is_holding, 3.0, "exfil state reached the late joiner")
	assert_eq(_barrier(late).planks, 5)
	assert_eq(_vault(late).state, SpecimenVault.State.OFFERING)
	assert_eq(_vault(late).offer, _vault(server).offer)
	assert_true(_hatch(late).is_open)
	assert_almost_eq(_hatch(late).hold_left, _hatch(server).hold_left, 0.5)
	assert_true(late.level.power_on)

## Two ENet peers prove well claims pay their sender and refuse invalid requests.
extends "res://tests/unit/well_claims_fixture.gd"


func test_client_claim_kill_pays_the_claiming_player_instead_of_the_host() -> void:
	var pair: Array[Zombie] = await _spawn_pair()
	pair[0].health.reset(1.0)
	_client_wells.request_well(Vector3.ZERO, SIPHON)
	await wait_until(func() -> bool: return _wells(_server).size() == 1, 3.0, "server accepted well")
	var well: GravityWell = _wells(_server)[0]
	assert_same(well.attacker, _server.players.find_player(_peer_id))
	well.tick(0.5)
	assert_true(pair[0].health.is_dead)
	var expected: int = _server.economy.rules.points_per_hit + _server.economy.rules.points_per_kill
	assert_eq(_server.players.find_player(_peer_id).wallet.points, expected)
	assert_eq(_server.players.find_player(1).wallet.points, 0)
	await wait_until(
		func() -> bool: return _client.players.find_player(_peer_id).wallet.points == expected,
		3.0,
		"claimant received their points"
	)


func test_client_well_is_cosmetic_and_cannot_damage_either_zombie_copy() -> void:
	var pair: Array[Zombie] = await _spawn_pair()
	_client_wells.request_well(Vector3.ZERO, SIPHON)
	await wait_until(func() -> bool: return _wells(_client).size() == 1, 3.0, "client received cosmetic well")
	var well: GravityWell = _wells(_client)[0]
	assert_false(well.gameplay)
	var server_health: float = pair[0].health.current
	var client_health: float = pair[1].health.current
	well.gameplay = true
	well.tick(0.5)
	assert_eq(pair[0].health.current, server_health)
	assert_eq(pair[1].health.current, client_health)


func test_out_of_range_client_claim_is_refused() -> void:
	var before: int = _rejections()
	_client_wells.request_well(Vector3(1000.0, 0.0, 0.0), SIPHON)
	await wait_until(func() -> bool: return _rejections() > before, 3.0, "range rejection reached server")
	assert_eq(_wells(_server).size(), 0)
	assert_eq(_wells(_client).size(), 0)


func test_nonfinite_client_claim_is_refused() -> void:
	var before: int = _rejections()
	_client_wells.request_well(Vector3(NAN, 0.0, 0.0), SIPHON)
	await wait_until(func() -> bool: return _rejections() > before, 3.0, "NaN rejection reached server")
	assert_eq(_wells(_server).size(), 0)


func test_dead_claiming_player_cannot_open_a_well() -> void:
	_server.players.find_player(_peer_id).health.is_dead = true
	var before: int = _rejections()
	_client_wells.request_well(Vector3.ZERO, SIPHON)
	await wait_until(func() -> bool: return _rejections() > before, 3.0, "dead shooter rejection reached server")
	assert_eq(_wells(_server).size(), 0)


func test_two_client_wells_do_not_block_the_hosts_own_well() -> void:
	for count: int in range(1, 3):
		_client_wells.request_well(Vector3.ZERO, SIPHON)
		await wait_until(func() -> bool: return _wells(_server).size() == count, 3.0, "client well accepted")
	var before: int = _rejections()
	_client_wells.request_well(Vector3.ZERO, SIPHON)
	await wait_until(func() -> bool: return _rejections() > before, 3.0, "third client well refused")
	assert_eq(_wells(_server).size(), 2)
	_server_wells.request_well(Vector3.ZERO, SIPHON)
	assert_eq(_wells(_server).size(), 3)
	assert_same(_wells(_server)[2].attacker, _server.players.find_player(1))


func test_rpm_limit_still_applies_after_wells_have_collapsed() -> void:
	for _claim: int in 3:
		_client_wells.request_well(Vector3.ZERO, SIPHON)
		await wait_until(func() -> bool: return _wells(_server).size() == 1, 3.0, "claim within RPM slack")
		_wells(_server)[0].collapse()
		for cosmetic: GravityWell in _wells(_client):
			cosmetic.collapse()
	var before: int = _rejections()
	_client_wells.request_well(Vector3.ZERO, SIPHON)
	await wait_until(func() -> bool: return _rejections() > before, 3.0, "excessive claim refused")
	assert_eq(_wells(_server).size(), 0)
	_server_claims._physics_process(1.1)
	_client_wells.request_well(Vector3.ZERO, SIPHON)
	await wait_until(func() -> bool: return _wells(_server).size() == 1, 3.0, "expired RPM window accepts claim")


func test_host_request_opens_directly_without_a_client_claim() -> void:
	_server_wells.request_well(Vector3(2.0, 0.0, 0.0), SIPHON)
	assert_eq(_wells(_server).size(), 1)
	assert_same(_wells(_server)[0].attacker, _server.players.find_player(1))


func test_owning_client_fires_an_orb_and_claims_only_when_it_lands() -> void:
	var player: Player = _client.players.find_player(_peer_id)
	var weapon: Weapon = player.weapons.give(Content.weapon(&"siphon"))
	weapon.fire()
	assert_eq(_wells(_server).size(), 0, "firing does not open a well instantly")
	var orb: GravityWell
	for child: Node in _client.get_children():
		if child is GravityWell and not child.is_in_group(&"gravity_wells"):
			orb = child as GravityWell
	assert_not_null(orb, "owning client created its orb")
	if orb == null:
		return
	assert_same(orb._claims, _client_wells, "the orb claims through WellClaims")
	await wait_until(
		func() -> bool: return _server_wells._well_launches.has(_peer_id), 3.0, "orb launch reached server WellClaims"
	)
	orb.set_physics_process(false)
	orb._tick_orb(2.5)
	await wait_until(func() -> bool: return _wells(_server).size() == 1, 3.0, "landing claim opened server well")
	assert_same(_wells(_server)[0].attacker, _server.players.find_player(_peer_id))


func test_claimant_receives_hit_and_kill_feedback_from_well_pulses() -> void:
	var pair: Array[Zombie] = await _spawn_pair()
	watch_signals(Events)
	_client_wells.request_well(Vector3.ZERO, SIPHON)
	await wait_until(func() -> bool: return _wells(_server).size() == 1, 3.0, "server accepted well")
	var well: GravityWell = _wells(_server)[0]
	well.set_physics_process(false)
	well.tick(0.5)
	await wait_until(
		func() -> bool: return get_signal_emit_count(Events, "hit_confirmed") == 2, 3.0, "owner received hit feedback"
	)
	var player: Player = _client.players.find_player(_peer_id)
	assert_signal_emitted_with_parameters(Events, "hit_confirmed", [player, false, false])
	pair[0].health.reset(1.0)
	well.tick(0.5)
	await wait_until(
		func() -> bool: return get_signal_emit_count(Events, "hit_confirmed") == 4, 3.0, "owner received kill feedback"
	)
	assert_signal_emitted_with_parameters(Events, "hit_confirmed", [player, true, false])


func test_host_landing_uses_launch_origin_after_the_shooter_moves() -> void:
	var player: Player = _server.players.find_player(1)
	var origin: Vector3 = player.camera.global_position
	_server_wells.send_well_orb(origin, Vector3.FORWARD, SIPHON)
	player.position += Vector3.BACK * 10.0
	_server_wells.request_well(origin + Vector3.FORWARD * 25.0, SIPHON)
	assert_eq(_wells(_server).size(), 1)


func test_client_landing_uses_launch_origin_after_the_shooter_moves() -> void:
	var player: Player = _client.players.find_player(_peer_id)
	var origin: Vector3 = player.camera.global_position
	_client_wells.send_well_orb(origin, Vector3.FORWARD, SIPHON)
	await wait_until(
		func() -> bool: return _server_wells._well_launches.has(_peer_id), 3.0, "server recorded launch origin"
	)
	player.position += Vector3.BACK * 10.0
	_server.players.find_player(_peer_id).position = player.position
	_client_wells.request_well(origin + Vector3.FORWARD * 25.0, SIPHON)
	await wait_until(func() -> bool: return _wells(_server).size() == 1, 3.0, "moving shooter landing accepted")


func test_two_orbs_in_flight_can_land_in_reverse_launch_order() -> void:
	var player: Player = _server.players.find_player(1)
	var first: Vector3 = player.camera.global_position
	_server_wells.send_well_orb(first, Vector3.FORWARD, SIPHON)
	player.position += Vector3.RIGHT * 7.5
	var second: Vector3 = player.camera.global_position
	_server_wells.send_well_orb(second, Vector3.FORWARD, SIPHON)
	player.position += Vector3.BACK * 10.0
	_server_wells.request_well(second + Vector3.FORWARD * 25.0, SIPHON)
	_server_wells.request_well(first + Vector3.FORWARD * 25.0, SIPHON)
	assert_eq(_wells(_server).size(), 2)


func test_landing_outside_all_recorded_launch_ranges_is_refused() -> void:
	var player: Player = _server.players.find_player(1)
	_server_wells.send_well_orb(player.camera.global_position, Vector3.FORWARD, SIPHON)
	player.position += Vector3.RIGHT * 7.5
	_server_wells.send_well_orb(player.camera.global_position, Vector3.FORWARD, SIPHON)
	_server_wells.request_well(Vector3(1000.0, 0.0, 0.0), SIPHON)
	assert_eq(_wells(_server).size(), 0)


func test_expired_launch_origin_does_not_expand_the_claim_range() -> void:
	var player: Player = _server.players.find_player(1)
	var origin: Vector3 = player.camera.global_position
	_server_wells.send_well_orb(origin, Vector3.FORWARD, SIPHON)
	_server_wells._physics_process(3.6)
	player.position += Vector3.BACK * 10.0
	_server_wells.request_well(origin + Vector3.FORWARD * 25.0, SIPHON)
	assert_eq(_wells(_server).size(), 0)

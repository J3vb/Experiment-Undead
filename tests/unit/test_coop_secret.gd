## Two ENet peers and a late joiner: a client solves the Signal in the Static radios,
## the server opens the freezer for everyone, and the Cryo Lance rack gives each
## player one gun for free.
extends "res://tests/unit/coop_interaction_fixture.gd"


func port() -> int:
	return 24709


func _radio(session: GameSession, i: int) -> WallRadio:
	return session.level.get_node("Puzzle/Radio%d" % i) as WallRadio


func _radio_with_pitch(session: GameSession, rank: int) -> String:
	for i: int in 3:
		if _radio(session, i).pitch == rank:
			return "Puzzle/Radio%d" % i
	return ""


func _solve() -> void:
	server.level.turn_power_on()
	await wait_until(func() -> bool: return _radio(client, 2).pitch >= 0, 3.0, "pitches reached the client")
	for rank: int in 3:
		var node_name: String = _radio_with_pitch(client, rank)
		await press(node_name)
		server.interactions._time += 1.0
		await wait_until(
			func() -> bool: return (target(client, node_name) as WallRadio).lit, 3.0, "radio %d lit" % rank
		)


func test_client_solves_the_radios_and_the_freezer_opens_everywhere() -> void:
	await _solve()
	await wait_until(func() -> bool: return gone(client, "FreezerDoor"), 3.0, "freezer open on the client")
	assert_true(gone(server, "FreezerDoor"))
	assert_true(client.level.open_areas.has(&"cold_room"))


func test_wrong_press_resets_the_radios_for_everyone() -> void:
	server.level.turn_power_on()
	await wait_until(func() -> bool: return _radio(client, 2).pitch >= 0, 3.0, "pitches reached the client")
	await press(_radio_with_pitch(client, 1))
	await wait_physics_frames(6)
	for i: int in 3:
		assert_false(_radio(server, i).lit)
		assert_false(_radio(client, i).lit)
	assert_false(gone(client, "FreezerDoor"))


func test_rack_gives_one_cryo_lance_per_player() -> void:
	await press("Rack")
	await wait_until(func() -> bool: return on_client().weapons.weapons.size() == 1, 3.0, "lance granted")
	assert_eq(on_client().weapons.current.data.id, &"cryo_lance")
	assert_eq((target(server, "Rack") as WallBuy).taken_by, [client_id] as Array[int])
	server.interactions._time += 1.0
	client.interactions.request_interact.rpc_id(1, ^"Rack", {"owned": &"", "slot": 1, "full": false})
	await wait_until(func() -> bool: return not server.interactions._pending.has(client_id), 3.0, "server read it")
	await wait_physics_frames(6)
	assert_eq(on_client().weapons.weapons.size(), 1, "a second take is refused, even claiming no lance")


func test_late_joiner_sees_lit_radios_and_the_open_freezer() -> void:
	await _solve()
	late = make_side("InteractLate")
	add_player(late, client_id)
	await join(late)
	await wait_until(func() -> bool: return gone(late, "FreezerDoor"), 3.0, "late joiner sees it open")
	for i: int in 3:
		assert_true(_radio(late, i).lit)

## Two ENet peers: the server's round start, end and intermission reach the
## client as the same Events; a late joiner catches up from a snapshot; a
## client never runs the round loop itself.
extends "res://tests/unit/coop_interaction_fixture.gd"

const WAVES: String = "res://content/waves/default_waves.tres"

var _spawner: Spawner


func port() -> int:
	return 24713


func before_each() -> void:
	await super.before_each()
	_spawner = Spawner.new()
	var director: WaveDirector = _director(server)
	director.rules = load(WAVES) as WaveRules
	director.session = server
	director.spawner = _spawner


func after_each() -> void:
	_spawner.free()
	super.after_each()


func _director(session: GameSession) -> WaveDirector:
	return session.get_node("WaveDirector") as WaveDirector


func test_round_start_reaches_the_client_with_the_same_numbers() -> void:
	watch_signals(Events)
	_director(server).skip_to_round(3)
	var expected: int = _director(server).to_spawn
	await wait_until(func() -> bool: return _director(client).round_number == 3, 3.0, "round reached the client")
	assert_signal_emitted_with_parameters(Events, "round_started", [3, expected])
	assert_eq(_director(client).phase, WaveDirector.Phase.SPAWNING)


func test_round_end_and_intermission_reach_the_client() -> void:
	var director: WaveDirector = _director(server)
	director.skip_to_round(2)
	await wait_until(func() -> bool: return _director(client).round_number == 2, 3.0, "round reached the client")
	watch_signals(Events)
	director.phase = WaveDirector.Phase.CLEARING
	director._check_round_end()
	await wait_until(
		func() -> bool: return _director(client).phase == WaveDirector.Phase.INTERMISSION, 3.0, "break reached"
	)
	assert_signal_emitted_with_parameters(Events, "round_ended", [2])
	assert_signal_emitted_with_parameters(Events, "intermission_started", [3, director.rules.intermission_time])


func test_late_joiner_mid_round_gets_the_round_number() -> void:
	_director(server).skip_to_round(7)
	late = make_side("InteractLate")
	add_player(late, client_id)
	watch_signals(Events)
	await join(late)
	await wait_until(func() -> bool: return _director(late).round_number == 7, 3.0, "snapshot reached the joiner")
	assert_eq(_director(late).phase, WaveDirector.Phase.SPAWNING)
	assert_signal_emitted(Events, "round_started")


func test_late_joiner_in_intermission_gets_the_time_left() -> void:
	_director(server).start()
	var left: float = _director(server)._timer
	late = make_side("InteractLate")
	add_player(late, client_id)
	watch_signals(Events)
	await join(late)
	await wait_until(func() -> bool: return get_signal_emit_count(Events, "intermission_started") > 0, 3.0, "sent")
	var params: Array = get_signal_parameters(Events, "intermission_started")
	assert_eq(params[0], 1)
	assert_almost_eq(float(params[1]), left, 0.2)
	assert_eq(_director(late).phase, WaveDirector.Phase.INTERMISSION)


func test_client_does_not_run_the_round_loop_from_a_snapshot() -> void:
	var director: WaveDirector = _director(client)
	director._timer = 0.1
	director.phase = WaveDirector.Phase.INTERMISSION
	watch_signals(Events)
	await wait_physics_frames(30)
	assert_signal_not_emitted(Events, "round_started")
	assert_eq(director.round_number, 0)
	director.phase = WaveDirector.Phase.SPAWNING
	director.to_spawn = 5
	await wait_physics_frames(30)
	assert_eq(director.to_spawn, 5, "a client never counts spawns down")


func test_round_message_from_a_client_is_ignored() -> void:
	var director: WaveDirector = _director(server)
	director._receive_round(WaveDirector.Message.STARTED, 9, 4.0, true)
	assert_eq(director.round_number, 0, "the server never takes round numbers from anyone")
	assert_false(director.blackout, "nor a Blackout")


func test_blackout_reaches_the_client_and_ends_there() -> void:
	watch_signals(Events)
	_director(server).skip_to_round(6)
	_director(server).set_blackout(true)
	await wait_until(func() -> bool: return _director(client).blackout, 3.0, "Blackout reached the client")
	assert_signal_emitted_with_parameters(Events, "blackout_started", [6])
	_director(server).set_blackout(false)
	await wait_until(func() -> bool: return not _director(client).blackout, 3.0, "lights back on the client")
	assert_signal_emitted_with_parameters(Events, "blackout_ended", [6])


func test_round_start_carries_the_blackout() -> void:
	var director: WaveDirector = _director(server)
	director.blackout = true
	director.skip_to_round(6)
	await wait_until(func() -> bool: return _director(client).round_number == 6, 3.0, "round reached the client")
	assert_true(_director(client).blackout, "the round start says the lights are out")


func test_late_joiner_mid_blackout_gets_dark_lights() -> void:
	_director(server).skip_to_round(6)
	_director(server).set_blackout(true)
	late = make_side("InteractLate")
	add_player(late, client_id)
	watch_signals(Events)
	await join(late)
	await wait_until(func() -> bool: return _director(late).blackout, 3.0, "snapshot carried the Blackout")
	assert_signal_emitted(Events, "blackout_started")

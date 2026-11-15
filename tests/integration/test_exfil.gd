## The exfil hatch on Halcyon Labs: opens from round 10 every 5th round,
## counts only while a living player holds it, and ends the match with +50% XP.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession
var player: Player
var hatch: ExfilHatch


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	session.rng_seed = 7
	session.restart_delay = 0.1
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	session.director.stop()
	player = session.get_players()[0]
	hatch = get_tree().get_first_node_in_group(&"exfil") as ExfilHatch


func test_opens_from_round_10_every_5th_round() -> void:
	for round_number: int in [1, 5, 9, 11, 14]:
		Events.round_started.emit(round_number, 10)
		assert_false(hatch.is_open, "closed in round %d" % round_number)
	for round_number: int in [10, 15, 20]:
		Events.round_started.emit(round_number, 10)
		assert_true(hatch.is_open, "open in round %d" % round_number)
		assert_eq(hatch.get_prompt(player), "Call exfil [F]")
		Events.round_ended.emit(round_number)
		assert_false(hatch.is_open, "closes when the round ends uncalled")


func test_closed_hatch_cannot_be_called() -> void:
	hatch.interact(player)
	assert_false(hatch.is_holding)
	assert_eq(hatch.get_prompt(player), "")


func test_hold_counts_only_with_a_player_in_the_zone() -> void:
	Events.round_started.emit(10, 10)
	hatch.interact(player)
	assert_true(hatch.is_holding)
	player.global_position = hatch.global_position + Vector3(20, 0, 0)
	hatch._physics_process(10.0)
	assert_almost_eq(hatch.hold_left, 60.0, 0.5, "nobody on the hatch")
	player.global_position = hatch.global_position + Vector3(2, 0.1, 0)
	hatch._physics_process(10.0)
	assert_almost_eq(hatch.hold_left, 50.0, 0.5, "counts while held")


func test_called_exfil_stays_open_after_the_round() -> void:
	Events.round_started.emit(10, 10)
	hatch.interact(player)
	Events.round_ended.emit(10)
	assert_true(hatch.is_open)
	assert_true(hatch.is_holding)


func test_finished_exfil_ends_the_match_with_bonus_xp() -> void:
	session.progression.add_xp(player, 1000)
	watch_signals(Events)
	Events.round_started.emit(10, 10)
	hatch.interact(player)
	player.global_position = hatch.global_position + Vector3(0, 0.1, 0)
	hatch._physics_process(61.0)
	assert_true(session.is_over)
	assert_eq(session.progression.get_xp(player), 1500)
	assert_eq(session.level.process_mode, Node.PROCESS_MODE_DISABLED, "world frozen")
	await wait_for_signal(Events.game_over, 2.0)
	var stats: Dictionary = get_signal_parameters(Events, "game_over")[0]
	assert_true(stats.get("exfil", false))

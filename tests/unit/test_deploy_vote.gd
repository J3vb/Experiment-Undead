## The hub's ready-up vote: a server with no local player, a client and a late joiner.
## Votes come from the server-side request the deploy board makes.
extends "res://tests/unit/coop_interaction_fixture.gd"

var _events: Array[Array] = []
var _places: Array[StringName] = []


func before_each() -> void:
	await super()
	_events.clear()
	_places.clear()
	server.is_hub = true
	server.has_local_player = false
	add_vote(server)
	add_vote(client)
	Events.deploy_vote_changed.connect(_on_vote_changed)
	Net.place_changed.connect(_on_place_changed)


func after_each() -> void:
	Events.deploy_vote_changed.disconnect(_on_vote_changed)
	Net.place_changed.disconnect(_on_place_changed)
	Net.place = &""
	super()


func add_vote(session: GameSession) -> void:
	session.deploy_vote = DeployVote.new()
	session.deploy_vote.session = session
	session.add_child(session.deploy_vote)


func add_late_joiner() -> int:
	late = make_side("InteractLate")
	add_vote(late)
	add_player(late, client_id)
	await join(late)
	var late_id: int = late.multiplayer.get_unique_id()
	add_player(server, late_id)
	await wait_physics_frames(4)
	return late_id


func ready_up(peer_id: int, place: StringName = &"match") -> void:
	server.deploy_vote.toggle_ready(on_server(peer_id), place)
	await wait_physics_frames(4)


func _on_vote_changed(place: StringName, ready_ids: Array[int], countdown_left: float) -> void:
	_events.append([place, ready_ids, countdown_left])


func _on_place_changed(place: StringName) -> void:
	_places.append(place)


func test_first_press_proposes_and_readies_and_every_peer_hears_it() -> void:
	var late_id: int = await add_late_joiner()
	await ready_up(client_id)
	assert_eq(server.deploy_vote.place, &"match")
	assert_true(server.deploy_vote.is_ready(client_id))
	assert_false(server.deploy_vote.is_ready(late_id), "others are not ready yet")
	assert_eq(client.deploy_vote.place, &"match", "the client heard the vote")
	assert_true(client.deploy_vote.is_ready(client_id))
	assert_eq(late.deploy_vote.place, &"match", "the other client heard the vote")
	assert_eq(server.deploy_vote.countdown_left(), 0.0, "no countdown while someone is not ready")
	assert_eq(_events.back(), [&"match", [client_id] as Array[int], 0.0])


func test_a_press_for_another_place_is_ignored_while_a_vote_runs() -> void:
	var late_id: int = await add_late_joiner()
	await ready_up(client_id)
	await ready_up(late_id, &"hub")
	assert_eq(server.deploy_vote.place, &"match")
	assert_false(server.deploy_vote.is_ready(late_id))


func test_an_unknown_place_never_starts_a_vote() -> void:
	await ready_up(client_id, &"no_such_place")
	assert_eq(server.deploy_vote.place, &"")
	assert_eq(_places, [] as Array[StringName])


func test_pressing_again_unreadies_and_the_last_unready_ends_the_vote() -> void:
	var late_id: int = await add_late_joiner()
	await ready_up(client_id)
	await ready_up(late_id)
	assert_gt(server.deploy_vote.countdown_left(), 0.0, "everyone ready starts the countdown")
	await ready_up(late_id)
	assert_false(server.deploy_vote.is_ready(late_id))
	assert_eq(server.deploy_vote.countdown_left(), 0.0, "any un-ready cancels the countdown")
	assert_eq(server.deploy_vote.place, &"match", "the vote stays while someone is ready")
	await ready_up(client_id)
	assert_eq(server.deploy_vote.place, &"", "nobody ready ends the vote")
	assert_eq(client.deploy_vote.place, &"")
	assert_eq(_events.back(), [&"", [] as Array[int], 0.0])


func test_everyone_ready_counts_down_then_deploys() -> void:
	await ready_up(client_id)
	assert_almost_eq(server.deploy_vote.countdown_left(), DeployVote.COUNTDOWN, 0.2)
	assert_gt(client.deploy_vote.countdown_left(), 0.0, "the client sees the countdown")
	assert_eq(_places, [] as Array[StringName], "no deploy before the countdown ends")
	server.deploy_vote._countdown = 0.05
	await wait_physics_frames(10)
	assert_eq(_places, [&"match"] as Array[StringName], "the server changed place once")
	assert_eq(Net.place, &"match")
	assert_eq(server.deploy_vote.place, &"", "the vote is over")


func test_a_joiner_stops_the_countdown_and_a_leaver_restarts_it() -> void:
	await ready_up(client_id)
	assert_gt(server.deploy_vote.countdown_left(), 0.0)
	var late_id: int = await add_late_joiner()
	assert_eq(server.deploy_vote.countdown_left(), 0.0, "a joiner starts not ready")
	assert_false(server.deploy_vote.is_ready(late_id))
	assert_eq(late.deploy_vote.place, &"match", "the late joiner got the running vote")
	assert_true(late.deploy_vote.is_ready(client_id))
	_sessions.erase(late)
	TwoPeers.close_side(late.get_parent())
	on_server(late_id).free()
	await wait_until(func() -> bool: return server.deploy_vote.countdown_left() > 0.0, 3.0, "leaver re-checked")
	assert_gt(server.deploy_vote.countdown_left(), 0.0, "everyone left is ready again")


func test_a_ready_player_who_leaves_is_dropped() -> void:
	var late_id: int = await add_late_joiner()
	await ready_up(late_id)
	_sessions.erase(late)
	TwoPeers.close_side(late.get_parent())
	on_server(late_id).free()
	await wait_until(func() -> bool: return server.deploy_vote.place == &"", 3.0, "vote ended")
	assert_false(server.deploy_vote.is_ready(late_id))
	assert_eq(client.deploy_vote.place, &"")


func test_outside_the_hub_there_is_no_vote_and_no_deploy() -> void:
	server.is_hub = false
	await ready_up(client_id)
	assert_eq(server.deploy_vote.place, &"")
	assert_false(server.deploy_vote.deploy(&"match"))
	assert_eq(_places, [] as Array[StringName])


func test_a_client_cannot_deploy() -> void:
	client.is_hub = true
	assert_false(client.deploy_vote.deploy(&"match"))
	assert_eq(_places, [] as Array[StringName])


func test_the_hub_never_starts_waves() -> void:
	server._try_start()
	assert_eq(server.director.phase, WaveDirector.Phase.IDLE)


func test_a_peer_change_that_lands_after_the_hub_closed_does_nothing() -> void:
	var vote: DeployVote = server.deploy_vote
	vote.place = &"match"
	server.remove_child(vote)
	vote._on_peers_changed()
	assert_engine_error_count(0, "a hub closing under a deferred peer change raises no script error")
	vote.free()

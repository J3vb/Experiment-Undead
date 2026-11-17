## A listen server with nobody else in it plays by the solo rules; the first friend
## switches it to co-op and the last one leaving switches it back (F-66 step 1).
extends "res://tests/unit/coop_interaction_fixture.gd"

var owner_player: Player


func before_each() -> void:
	_port = TwoPeers.next_port()
	_sessions.clear()
	late = null
	client = null
	server = make_side("SoloServer")
	assert_eq(TwoPeers.host(server, _port, 3), OK)
	owner_player = add_player(server, 1)
	owner_player.spawn(server, [] as Array[WeaponData])


func after_each() -> void:
	for session: GameSession in _sessions:
		if session != server:
			TwoPeers.close_side(session.get_parent())
	TwoPeers.close_side(server.get_parent())


func _friend_joins() -> void:
	client = make_side("SoloClient")
	add_player(client, 1)
	await join(client)
	client_id = client.multiplayer.get_unique_id()


func _friend_leaves() -> void:
	_sessions.erase(client)
	TwoPeers.close_side(client.get_parent())
	client = null
	await wait_until(func() -> bool: return server.multiplayer.get_peers().is_empty(), 3.0, "friend gone")


func test_a_lone_listen_server_follows_the_solo_rules() -> void:
	assert_false(Net.is_coop(server.multiplayer), "nobody else is connected")
	assert_false(owner_player.state_sync.is_coop())
	owner_player.take_damage(DamageInfo.create(10000.0, null))
	assert_true(owner_player.is_dead, "solo rule: no Second Wind means the run ends, no bleed-out")
	assert_false(owner_player.is_downed)


func test_a_friend_switches_to_coop_and_leaving_switches_back() -> void:
	await _friend_joins()
	assert_true(Net.is_coop(server.multiplayer), "a server with a friend plays co-op")
	assert_true(Net.is_coop(client.multiplayer), "a client always plays co-op")
	assert_true(owner_player.state_sync.is_coop())
	await _friend_leaves()
	assert_false(Net.is_coop(server.multiplayer), "alone again")
	assert_false(owner_player.state_sync.is_coop())


func test_a_friend_joining_during_solo_second_wind_does_not_kill_the_owner() -> void:
	owner_player.add_serum(Content.get_item(&"serums", &"second_wind") as SerumData)
	owner_player.second_wind_time = 0.4
	owner_player.take_damage(DamageInfo.create(10000.0, null))
	assert_true(owner_player.is_downed, "solo Second Wind keeps the owner down")
	assert_eq(owner_player.state_sync.bleed_left, 0.0, "a solo down has no bleed-out")
	await _friend_joins()
	await wait_physics_frames(3)
	assert_false(owner_player.is_dead, "the joiner does not turn the solo down into a bleed-out death")
	await wait_until(func() -> bool: return owner_player.is_alive(), 3.0, "Second Wind got the owner up")
	assert_false(owner_player.is_downed)
	assert_false(owner_player.is_dead)


func test_the_coop_down_waits_for_a_friend() -> void:
	owner_player.state_sync.down_player()
	assert_false(owner_player.is_downed, "alone there is no co-op down")
	await _friend_joins()
	var friend: Player = add_player(server, client_id)
	friend.spawn(server, [] as Array[WeaponData])
	owner_player.state_sync.down_player()
	assert_true(owner_player.is_downed, "co-op rule: the owner is downed and bleeds out")
	assert_gt(owner_player.state_sync.bleed_left, 0.0)
	assert_true(friend.revive.can_revive(owner_player), "a friend next to the owner can revive")

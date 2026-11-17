extends GutTest

const NetScript: GDScript = preload("res://core/net.gd")


func test_allocated_ids_are_unique_and_restart_from_one() -> void:
	var net_node: Node = NetScript.new()
	assert_eq(net_node.allocate_id(), 1)
	assert_eq(net_node.allocate_id(), 2)
	assert_eq(net_node.allocate_id(), 3)
	net_node.reset_ids()
	assert_eq(net_node.allocate_id(), 1)
	assert_eq(net_node.allocate_id(), 2)
	net_node.free()


func test_solo_is_authority() -> void:
	var net_node: Node = NetScript.new()
	add_child_autofree(net_node)
	assert_true(net_node.is_authority())


func test_parse_address_reads_port_or_uses_default() -> void:
	assert_eq(NetScript.parse_address("10.0.0.5:24600"), ["10.0.0.5", 24600])
	assert_eq(NetScript.parse_address(" myserver.lan "), ["myserver.lan", NetScript.DEFAULT_PORT])
	assert_eq(NetScript.parse_address("host:notaport"), ["host:notaport", NetScript.DEFAULT_PORT])
	assert_eq(NetScript.parse_address(""), ["127.0.0.1", NetScript.DEFAULT_PORT])


func test_host_goes_online_and_leave_returns_to_solo() -> void:
	assert_false(Net.is_online())
	assert_eq(Net.host(24631, 2), OK)
	assert_eq(Net.player_limit, 2, "hello admission uses the configured player limit")
	assert_true((multiplayer as SceneMultiplayer).auth_callback.is_valid(), "a transport waits for the match handshake")
	assert_true(Net.is_online())
	assert_true(Net.is_authority())
	Net.leave()
	assert_eq(Net.player_limit, Net.MAX_PLAYERS, "a match's player limit does not leak into the next session")
	assert_false(Net.is_online())
	assert_true(Net.is_authority())


func test_pending_join_is_used_once() -> void:
	Net.pending_join = "127.0.0.1:24632"
	assert_eq(Net.start_pending_join(), OK)
	assert_eq(Net.pending_join, "")
	assert_true(Net.is_online())
	assert_false(Net.is_authority(), "a client is not the authority")
	Net.leave()
	assert_eq(Net.start_pending_join(), OK, "nothing to join is fine")
	assert_false(Net.is_online())


func test_a_join_that_cannot_start_never_becomes_solo_play() -> void:
	Net.pending_join = "127.0.0.1:70000"
	var session: GameSession = (
		(load("res://systems/game/game_session.tscn") as PackedScene).instantiate() as GameSession
	)
	session.profile_id = &""
	add_child_autofree(session)
	assert_null(session.level, "the match stops before loading the map")
	assert_true(session.get_players().is_empty())
	assert_false(Net.is_online())
	assert_engine_error_count(2, "ENet refuses the bad port")


func after_each() -> void:
	Net.leave()
	Net.last_error.clear()


func test_cancel_stops_the_connection_deadline_without_an_error() -> void:
	assert_eq(Net.join("127.0.0.1:24655"), OK)
	assert_true(Net.joining)
	assert_false(Net._deadline.is_stopped())
	Net.leave()
	assert_false(Net.joining)
	assert_true(Net._deadline.is_stopped())
	assert_true(Net.last_error.is_empty())
	assert_false(Net.is_online())


func test_connection_deadline_records_one_failure_and_returns_offline() -> void:
	watch_signals(Net)
	assert_eq(Net.join("127.0.0.1:24655"), OK)
	Net._deadline.timeout.emit()
	assert_eq(Net.last_error, {"reason": &"timeout", "details": {"address": "127.0.0.1:24655"}})
	assert_signal_emit_count(Net, "connection_error", 1)
	assert_false(Net.joining)
	assert_false(Net.is_online())
	Net._deadline.timeout.emit()
	assert_signal_emit_count(Net, "connection_error", 1)


func test_failed_host_reports_the_port() -> void:
	var occupied: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(occupied.create_server(24656), OK)
	assert_ne(Net.host(24656), OK)
	assert_engine_error_count(1, "ENet refuses the occupied port")
	assert_eq(Net.last_error, {"reason": &"port_in_use", "details": {"port": 24656}})
	occupied.close()


func test_content_fingerprint_is_repeatable_and_resource_values_matter() -> void:
	assert_eq(Build.content_fingerprint(), Build.content_fingerprint())
	var weapon: WeaponData = Content.weapon(&"rifle_ar").duplicate(true) as WeaponData
	var before: String = Build._content_value(weapon)
	weapon.damage += 1.0
	assert_ne(Build._content_value(weapon), before)


func test_connection_configuration_preserves_the_match_handshake() -> void:
	var handshake: Handshake = Handshake.new()
	add_child(handshake)
	handshake.setup()
	var callback: Callable = (multiplayer as SceneMultiplayer).auth_callback
	assert_eq(Net.join("127.0.0.1:24655"), OK)
	assert_eq((multiplayer as SceneMultiplayer).auth_callback, callback, "Net never installs a competing hello")
	Net.leave()
	handshake.free()


func _admit_everyone(api: SceneMultiplayer) -> Callable:
	var admit: Callable = func(peer_id: int) -> void: api.complete_auth(peer_id)
	api.auth_callback = func(_peer_id: int, _data: PackedByteArray) -> void: pass
	api.peer_authenticating.connect(admit)
	return admit


func test_coop_switches_on_with_the_first_friend_and_off_with_the_last() -> void:
	var api: SceneMultiplayer = multiplayer as SceneMultiplayer
	var callback: Callable = api.auth_callback
	var admit: Callable = _admit_everyone(api)
	watch_signals(Net)
	assert_eq(Net.host(24657, 2), OK)
	assert_false(Net.is_coop(), "a world with nobody else in it plays solo")
	var friend: Node = TwoPeers.make_side(self, "Friend")
	_admit_everyone(friend.multiplayer as SceneMultiplayer)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", 24657), OK)
	friend.multiplayer.multiplayer_peer = peer
	await wait_until(func() -> bool: return not multiplayer.get_peers().is_empty(), 5.0, "friend connected")
	assert_true(Net.is_coop())
	assert_true(Net.is_coop(friend.multiplayer), "a client always plays co-op")
	assert_signal_emit_count(Net, "coop_changed", 1)
	assert_eq(get_signal_parameters(Net, "coop_changed"), [true])
	TwoPeers.close_side(friend)
	await wait_until(func() -> bool: return multiplayer.get_peers().is_empty(), 5.0, "friend gone")
	await wait_process_frames(1)
	assert_false(Net.is_coop())
	assert_signal_emit_count(Net, "coop_changed", 2)
	assert_eq(get_signal_parameters(Net, "coop_changed"), [false])
	Net.leave()
	assert_signal_emit_count(Net, "coop_changed", 2, "leaving alone changes nothing")
	api.peer_authenticating.disconnect(admit)
	api.auth_callback = callback

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
	assert_true(Net.is_online())
	assert_true(Net.is_authority())
	Net.leave()
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

## ServerInfo: the info packets, the reply checks, the answer caps and a live world answering browsers.
extends GutTest

const NONCE: PackedByteArray = [1, 2, 3, 4, 5, 6, 7, 8]
const GAME_PORT: int = 24680

var _client: PacketPeerUDP


func before_each() -> void:
	_client = PacketPeerUDP.new()
	assert_eq(_client.bind(0, "127.0.0.1"), OK)


func after_each() -> void:
	_client.close()
	Net.info.stop()
	get_tree().paused = false


func _info() -> Dictionary:
	return {"name": "Night shift", "players": 3, "max": 8, "playing": "Lantern Post", "version": "0.1", "protocol": 4}


func test_a_query_is_64_bytes_with_the_nonce() -> void:
	var query: PackedByteArray = ServerInfo.make_query(NONCE)
	assert_eq(query.size(), ServerInfo.QUERY_SIZE)
	assert_eq(ServerInfo.query_nonce(query), NONCE)
	assert_true(ServerInfo.query_nonce(query.slice(0, 40)).is_empty(), "short query")
	var wrong: PackedByteArray = query.duplicate()
	wrong[0] = 0
	assert_true(ServerInfo.query_nonce(wrong).is_empty(), "wrong magic")


func test_a_reply_round_trips_with_whole_numbers() -> void:
	var info: Dictionary = ServerInfo.parse_reply(ServerInfo.make_reply(NONCE, _info()), NONCE)
	assert_eq(info, _info())
	assert_true(info.players is int)
	assert_eq(info.keys().size(), ServerInfo.FIELDS.size(), "the frozen keys")


func test_a_long_name_is_cut_and_the_reply_stays_small() -> void:
	var info: Dictionary = _info()
	info.name = "x".repeat(400)
	info.playing = "Halcyon Labs, round 99"
	var reply: PackedByteArray = ServerInfo.make_reply(NONCE, info)
	assert_lt(reply.size(), ServerInfo.MAX_REPLY)
	assert_eq(str(ServerInfo.parse_reply(reply, NONCE).name).length(), ServerInfo.NAME_LENGTH)


func test_the_parser_drops_wrong_nonces_big_packets_and_wrong_types() -> void:
	assert_eq(
		ServerInfo.parse_reply(ServerInfo.make_reply(NONCE, _info()), PackedByteArray([9, 9, 9, 9, 9, 9, 9, 9])), {}
	)
	var big: PackedByteArray = ServerInfo.make_reply(NONCE, _info())
	big.resize(ServerInfo.MAX_REPLY + 1)
	assert_eq(ServerInfo.parse_reply(big, NONCE), {})
	var wrong: Dictionary = _info()
	wrong.players = "three"
	assert_eq(ServerInfo.parse_reply(ServerInfo.make_reply(NONCE, wrong), NONCE), {})
	var missing: Dictionary = _info()
	missing.erase("version")
	assert_eq(ServerInfo.parse_reply(ServerInfo.make_reply(NONCE, missing), NONCE), {})
	var junk: PackedByteArray = ServerInfo.REPLY_MAGIC.to_ascii_buffer() + NONCE + "not json".to_utf8_buffer()
	assert_eq(ServerInfo.parse_reply(junk, NONCE), {})


func test_unknown_keys_are_ignored_so_later_versions_can_add_some() -> void:
	var newer: Dictionary = _info()
	newer["mods"] = ["more zombies"]
	assert_eq(ServerInfo.parse_reply(ServerInfo.make_reply(NONCE, newer), NONCE), _info())


func test_a_world_answers_on_the_game_port_plus_1000() -> void:
	assert_true(Net.info.start(GAME_PORT, "  Night shift  "))
	ServerInfo.send_queries(_client, NONCE, PackedInt32Array([GAME_PORT + 1000]), "127.0.0.1")
	var info: Dictionary = await _reply()
	assert_eq(info.get("name"), "Night shift")
	assert_eq(info.get("max"), Net.player_limit)
	assert_eq(info.get("version"), Build.version)
	assert_eq(info.get("protocol"), Build.PROTOCOL_VERSION)


func test_a_paused_world_still_answers() -> void:
	assert_true(Net.info.start(GAME_PORT, "Paused"))
	get_tree().paused = true
	ServerInfo.send_queries(_client, NONCE, PackedInt32Array([GAME_PORT + 1000]), "127.0.0.1")
	assert_eq((await _reply()).get("name"), "Paused")


func test_a_stopped_world_is_silent() -> void:
	Net.info.start(GAME_PORT, "Gone")
	Net.info.stop()
	assert_false(Net.info.is_running())
	ServerInfo.send_queries(_client, NONCE, PackedInt32Array([GAME_PORT + 1000]), "127.0.0.1")
	assert_eq(await _reply(), {})


func test_one_address_gets_two_answers_a_second() -> void:
	Net.info.start(GAME_PORT, "Capped")
	for i: int in 5:
		ServerInfo.send_queries(_client, NONCE, PackedInt32Array([GAME_PORT + 1000]), "127.0.0.1")
	await wait_physics_frames(10)
	var answers: int = 0
	while _client.get_available_packet_count() > 0:
		_client.get_packet()
		answers += 1
	assert_between(answers, 1, ServerInfo.PER_SOURCE)


func test_the_total_cap_stops_a_crowd() -> void:
	var info: ServerInfo = ServerInfo.new()
	var allowed: int = 0
	for i: int in 40:
		if info._allow("10.0.0.%d" % i):
			allowed += 1
	assert_lte(allowed, ServerInfo.TOTAL)
	assert_gte(allowed, ServerInfo.TOTAL - ServerInfo.PER_SOURCE * 2, "unless the second ticked over")
	info.free()


func test_a_bad_packet_is_dropped_and_logged() -> void:
	Net.info.start(GAME_PORT, "Picky")
	_client.set_dest_address("127.0.0.1", GAME_PORT + 1000)
	_client.put_packet("hello".to_ascii_buffer())
	await wait_physics_frames(5)
	assert_eq(_client.get_available_packet_count(), 0)


func test_a_busy_info_port_only_hides_the_world() -> void:
	var squatter: PacketPeerUDP = PacketPeerUDP.new()
	squatter.bind(GAME_PORT + 1000)
	assert_false(Net.info.start(GAME_PORT, "Hidden"))
	assert_false(Net.info.is_running())
	squatter.close()


func test_the_hub_shows_its_title() -> void:
	var old: StringName = Net.place
	Net.place = DeployVote.HUB
	assert_eq(Net.info.playing(), "Lantern Post")
	Net.place = old


func test_lan_discovery_reaches_a_world_by_broadcast() -> void:
	Net.info.start(GAME_PORT, "Next door")
	var lan: PacketPeerUDP = PacketPeerUDP.new()
	lan.bind(0)
	ServerInfo.send_queries(lan, NONCE, PackedInt32Array([GAME_PORT + 1000]))
	var info: Dictionary = await _reply(lan)
	lan.close()
	if info.is_empty():
		pending("This machine has no broadcast route")
		return
	assert_eq(info.get("name"), "Next door")


func _reply(socket: PacketPeerUDP = _client) -> Dictionary:
	for i: int in 30:
		await wait_physics_frames(1)
		while socket.get_available_packet_count() > 0:
			var info: Dictionary = ServerInfo.parse_reply(socket.get_packet(), NONCE)
			if not info.is_empty():
				return info
	return {}

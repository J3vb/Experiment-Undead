## Two ENet peers: a client asks the server to open doors and turn on the
## power; the server checks the request, charges points and every peer sees
## the result. Bad requests are refused and charge nothing.
extends "res://tests/unit/coop_interaction_fixture.gd"


func test_protocol_bumped_for_interaction_messages() -> void:
	assert_eq(Build.PROTOCOL_VERSION, 4)


func test_client_opens_a_door_on_every_peer() -> void:
	on_server().wallet.set_points(1000)
	var point: Node = server.level.get_node("EastSpawn")
	assert_false(point.is_in_group(&"enemy_spawn"))
	await press("EastDoor")
	await wait_until(func() -> bool: return gone(client, "EastDoor"), 3.0, "door gone on the client")
	assert_true(gone(server, "EastDoor"), "door gone on the server")
	assert_eq(on_server().wallet.points, 0, "server took the door cost")
	assert_true(point.is_in_group(&"enemy_spawn"), "the area's spawn points joined on the server")
	assert_true(client.level.open_areas.has(&"east"), "client knows the area is open")
	assert_false(gone(client, "WestDoor"), "other doors stay")


func test_client_turns_on_power_and_power_door_opens_everywhere() -> void:
	await press("PowerSwitch")
	await wait_until(func() -> bool: return client.level.power_on, 3.0, "power on the client")
	assert_true(server.level.power_on)
	await wait_until(func() -> bool: return gone(client, "PowerDoor"), 3.0, "power door gone on the client")
	assert_true(gone(server, "PowerDoor"))
	assert_true((target(client, "PowerSwitch").get_node("PowerSound") as AudioStreamPlayer3D).playing)


func test_out_of_range_request_is_refused() -> void:
	on_server().wallet.set_points(1000)
	on_client().global_position = Vector3(40, 0, 0)
	await wait_until(func() -> bool: return on_server().global_position.x > 39.0, 3.0, "pose reached the server")
	await press("EastDoor")
	await wait_until(func() -> bool: return denied_on(client, "EastDoor"), 3.0, "denied result reached the client")
	assert_false(gone(server, "EastDoor"))
	assert_eq(on_server().wallet.points, 1000)


func test_downed_player_is_refused() -> void:
	on_server().wallet.set_points(1000)
	on_server().state_sync.bleed_left = 30.0
	on_server().is_downed = true
	await press("EastDoor")
	await wait_until(func() -> bool: return denied_on(client, "EastDoor"), 3.0, "denied result reached the client")
	assert_false(gone(server, "EastDoor"))
	assert_eq(on_server().wallet.points, 1000)


func test_not_enough_points_is_denied_to_the_client() -> void:
	on_server().wallet.set_points(500)
	await press("EastDoor")
	await wait_until(func() -> bool: return denied_on(client, "EastDoor"), 3.0, "denied result reached the client")
	assert_false(gone(server, "EastDoor"))
	assert_false(gone(client, "EastDoor"))
	assert_eq(on_server().wallet.points, 500)


func test_unknown_or_escaping_paths_are_refused() -> void:
	on_server().wallet.set_points(1000)
	for path: NodePath in [^"Nope", ^"../Economy", ^"/root", ^""]:
		client.interactions.request_interact.rpc_id(1, path, {})
		await wait_physics_frames(6)
	assert_eq(on_server().wallet.points, 1000)
	assert_false(gone(server, "EastDoor"))


func test_second_request_inside_the_gap_is_refused() -> void:
	on_server().wallet.set_points(2000)
	client.interactions.request(on_client(), target(client, "EastDoor"))
	client.interactions.request(on_client(), target(client, "WestDoor"))
	await wait_until(func() -> bool: return gone(client, "EastDoor"), 3.0, "first door opened")
	await wait_physics_frames(6)
	assert_false(gone(server, "WestDoor"), "second request in the same tick refused")
	assert_eq(on_server().wallet.points, 1000)


func test_late_joiner_does_not_see_an_opened_door() -> void:
	on_server().wallet.set_points(1000)
	await press("EastDoor")
	await wait_until(func() -> bool: return gone(server, "EastDoor"), 3.0, "door opened")
	late = make_side("InteractLate")
	add_player(late, client_id)
	await join(late)
	await wait_until(func() -> bool: return gone(late, "EastDoor"), 3.0, "snapshot removed the door")
	assert_true(late.level.open_areas.has(&"east"))
	assert_false(gone(late, "WestDoor"))
	assert_false(late.level.power_on)


func test_refused_request_for_a_type_without_purchase_sounds_is_silent() -> void:
	on_server().state_sync.bleed_left = 30.0
	on_server().is_downed = true
	await press("PowerSwitch")
	await wait_physics_frames(6)
	assert_false(server.level.power_on, "downed players cannot turn on power")
	assert_false(client.level.power_on)

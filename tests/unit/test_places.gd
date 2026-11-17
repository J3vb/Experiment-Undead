## Changing places: the Net bookkeeping that makes a place change a quiet rejoin, and
## the dedicated server swapping its session from the hub to the match.
extends GutTest

const PORT: int = 24661

var _server: DedicatedServer


func after_each() -> void:
	if is_instance_valid(_server):
		_server.free()
		await wait_process_frames(2)
	Net.changing_place = false
	Net.leave()
	Net.place = &""
	Net.last_error.clear()


func test_a_planned_change_keeps_the_rejoin_through_leave() -> void:
	Net.pending_join = "127.0.0.1:%d" % PORT
	Net.changing_place = true
	Net.leave()
	assert_eq(Net.pending_join, "127.0.0.1:%d" % PORT, "the next session joins the same server")
	Net.changing_place = false
	Net.leave()
	assert_eq(Net.pending_join, "", "a normal leave forgets the address")


func test_a_listen_host_keeps_its_port_open_through_a_place_change() -> void:
	assert_eq(Net.host(PORT, 3), OK)
	Net.changing_place = true
	Net.leave()
	assert_true(Net.is_online(), "the old session leaving does not close the host")
	assert_eq(Net.start_pending_join(), OK)
	assert_true(Net.is_online())
	assert_true(Net.is_authority())
	assert_eq(Net.player_limit, 3, "the player limit carries over")
	assert_false(Net.changing_place, "the change is over once the new session starts")


func test_joining_ends_a_place_change_and_its_disconnect_is_not_an_error() -> void:
	Net.changing_place = true
	Net._on_server_disconnected()
	assert_true(Net.last_error.is_empty(), "a planned disconnect shows no error")
	assert_eq(Net.join("127.0.0.1:%d" % PORT), OK)
	assert_false(Net.changing_place)


func test_change_place_offline_records_the_place_and_tells_the_server() -> void:
	watch_signals(Net)
	Net.change_place(&"match")
	assert_eq(Net.place, &"match")
	assert_signal_emitted_with_parameters(Net, "place_changed", [&"match"])


func test_dedicated_server_starts_in_the_hub_and_swaps_to_the_match() -> void:
	OS.set_environment("EU_PORT", str(PORT))
	_server = DedicatedServer.new()
	get_tree().root.add_child(_server)
	OS.unset_environment("EU_PORT")
	await wait_until(func() -> bool: return is_instance_valid(_server.session) and _server.session.is_node_ready(), 5.0)
	var hub: GameSession = _server.session
	assert_true(hub.is_hub, "a dedicated server starts in the hub")
	assert_eq(Net.place, &"hub")
	assert_eq(str(hub.get_path()), "/root/GameSession")
	assert_eq(hub.director.phase, WaveDirector.Phase.IDLE, "the hub starts no waves")
	var hub_id: int = hub.get_instance_id()
	assert_true(hub.deploy_vote.deploy(&"match"))
	await wait_until(
		func() -> bool: return _server.session.get_instance_id() != hub_id and _server.session.is_node_ready(), 10.0
	)
	assert_false(is_instance_id_valid(hub_id), "the hub session is gone")
	assert_false(_server.session.is_hub, "the server now runs the match")
	assert_eq(str(_server.session.get_path()), "/root/GameSession")
	assert_eq(Net.place, &"match")
	assert_true(Net.is_online(), "the port stays open for the squad to rejoin")


func test_a_peer_on_its_way_out_gets_no_player() -> void:
	Net._leaving.assign([42])
	var spawner: PlayerSpawner = PlayerSpawner.new()
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	add_child_autofree(spawner)
	spawner._parent = world
	assert_null(spawner.add_peer(42))
	Net._leaving.clear()

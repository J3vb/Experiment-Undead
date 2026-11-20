## Drain mode (F-65 step 8): after a newer release is installed the dedicated server lets a
## match finish, refuses new players in the hub and quits with EXIT_UPDATE so the launcher or
## Docker runner restarts it on the new version.
extends GutTest

const PORT: int = 24681

var _server: DedicatedServer


func after_each() -> void:
	if is_instance_valid(_server):
		_server.free()
		await wait_process_frames(2)
	Net.changing_place = false
	Net.end_reason = "host_ended"
	Net.leave()
	Net.place = &""
	Net.last_error.clear()


func _start(place: StringName = &"hub") -> void:
	OS.set_environment("EU_PORT", str(PORT))
	_server = DedicatedServer.new()
	_server.start_place = place
	get_tree().root.add_child(_server)
	OS.unset_environment("EU_PORT")
	await wait_until(func() -> bool: return is_instance_valid(_server.session) and _server.session.is_node_ready(), 5.0)


func test_drain_file_comes_from_the_command_line_or_environment() -> void:
	OS.set_environment("EU_DRAIN_FILE", "/tmp/eu.drain")
	assert_eq(DedicatedServer.read_string_setting("drain-file", "EU_DRAIN_FILE"), "/tmp/eu.drain")
	OS.unset_environment("EU_DRAIN_FILE")
	assert_eq(DedicatedServer.read_string_setting("drain-file", "EU_DRAIN_FILE"), "")


func test_empty_hub_restarts_only_after_the_grace() -> void:
	await _start()
	assert_false(_server.drain_step(DedicatedServer.EMPTY_GRACE - 1.0, 0), "a squad changing place looks empty")
	assert_true(_server.session.handshake.draining, "the hub refuses new players while it drains")
	assert_true(_server.drain_step(1.0, 0))


func test_a_player_coming_back_resets_the_grace() -> void:
	await _start()
	assert_false(_server.drain_step(DedicatedServer.EMPTY_GRACE - 1.0, 0))
	_server.session.deploy_vote.deploy(&"match")
	await wait_until(func() -> bool: return not _server.session.is_hub and _server.session.is_node_ready(), 10.0)
	assert_false(_server.drain_step(1.0, 2), "a match with players plays on")
	assert_false(_server.session.handshake.draining, "rejoins into a running match still work")
	assert_false(_server.drain_step(DedicatedServer.EMPTY_GRACE - 1.0, 0), "the grace starts again")


func test_hub_with_players_restarts_at_once() -> void:
	await _start()
	assert_true(_server.drain_step(DedicatedServer.CHECK_EVERY, 3))


func test_match_with_players_waits_for_the_squad_to_return() -> void:
	await _start(&"match")
	for _tick: int in range(100):
		assert_false(_server.drain_step(DedicatedServer.CHECK_EVERY, 1))
	assert_false(_server.session.handshake.draining)

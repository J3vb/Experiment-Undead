## ServerQuery: asks listed servers, reports replies with ping, and times out the silent ones.
extends GutTest

const GAME_PORT: int = 24690

var query: ServerQuery
var _answers: Array[Array] = []


func before_each() -> void:
	query = ServerQuery.new()
	query.lan_ports = PackedInt32Array()
	_answers.clear()
	query.answered.connect(
		func(address: String, info: Dictionary, ping: int, lan: bool) -> void:
			_answers.append([address, info, ping, lan])
	)


func after_each() -> void:
	query.close()
	Net.info.stop()


func _poll_until(done: Callable) -> void:
	var deadline: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and not done.call():
		query.poll()
		await wait_physics_frames(1)


func test_a_listed_world_answers_under_the_address_you_saved() -> void:
	Net.info.start(GAME_PORT, "Asked directly")
	query.start(["127.0.0.1:%d" % GAME_PORT] as Array[String])
	await _poll_until(func() -> bool: return not _answers.is_empty())
	assert_eq(_answers.size(), 1)
	assert_eq(_answers[0][0], "127.0.0.1:%d" % GAME_PORT)
	assert_eq(_answers[0][1].name, "Asked directly")
	assert_gte(_answers[0][2], 0)
	assert_false(_answers[0][3], "asked by address, not found on the LAN")


func test_silent_servers_time_out_once() -> void:
	watch_signals(query)
	query.start(["127.0.0.1:%d" % (GAME_PORT + 1)] as Array[String])
	var timed_out: Array[bool] = [false]
	query.timed_out.connect(func() -> void: timed_out[0] = true)
	await _poll_until(func() -> bool: return timed_out[0])
	query.poll()
	assert_signal_emit_count(query, "timed_out", 1)
	assert_true(_answers.is_empty())


func test_a_bad_address_is_skipped() -> void:
	query.start(["not an address::"] as Array[String])
	query.poll()
	assert_true(_answers.is_empty())

## End to end: a real dedicated server starts in the hub, a real client joins from the
## menu, lands in the hub, the vote deploys, and the client rejoins into round 1. The
## match then ends: the server goes back to the hub while the client keeps its results.
extends GutTest

const PORT: int = 24671
const READY_FILE: String = "user://test_net_deploy.ready"

var _pids: Array[int] = []


func _launch(args: Array[String]) -> int:
	var all: PackedStringArray = PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://")])
	all.append_array(PackedStringArray(args))
	var pid: int = OS.create_process(OS.get_executable_path(), all)
	assert_gt(pid, 0, "started %s" % [args])
	_pids.append(pid)
	return pid


func after_all() -> void:
	for pid: int in _pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
	if FileAccess.file_exists(READY_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(READY_FILE))


func _events(pid: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for filename: String in DirAccess.get_files_at(Log.DIR):
		if not filename.ends_with("_%d.jsonl" % pid):
			continue
		for line: String in FileAccess.get_file_as_string(Log.DIR.path_join(filename)).split("\n", false):
			var entry: Variant = JSON.parse_string(line)
			if entry is Dictionary:
				events.append(entry)
	return events


func _names(pid: int) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in _events(pid):
		out.append(str(entry.get("event")))
	return out


func _errors(pid: int) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in _events(pid):
		if entry.get("level") == "error":
			out.append("%s %s" % [entry.get("event"), entry.get("data")])
	return out


func test_a_client_joins_the_hub_deploys_and_reaches_round_one() -> void:
	OS.set_environment("EU_READY_FILE", ProjectSettings.globalize_path(READY_FILE))
	var server: int = _launch(["res://tests/integration/net_deploy_server.tscn", "--", "--port=%d" % PORT])
	OS.unset_environment("EU_READY_FILE")
	await wait_until(func() -> bool: return FileAccess.file_exists(READY_FILE), 15.0, "server listening")
	var client: int = _launch(["--", "--join=127.0.0.1:%d" % PORT])
	await wait_until(func() -> bool: return _names(client).has("round_started"), 60.0, "client reached round 1")
	await wait_until(func() -> bool: return _names(server).has("round_started"), 10.0, "server log written")
	var client_events: Array[String] = _names(client)
	assert_true(client_events.has("round_started"), "the client follows the match's rounds")
	assert_eq(client_events.count("player_spawned") >= 2, true, "spawned in the hub, then in the match")
	assert_true(client_events.has("go_to_place"), "the server sent the client to the match")
	assert_false(client_events.has("connection_lost"), "the planned place change is not a lost connection")
	var server_events: Array[String] = _names(server)
	assert_true(server_events.has("place_changed"), "the server changed place")
	assert_true(server_events.has("round_started"), "the match started on the server")
	await wait_until(func() -> bool: return _names(client).has("place_change_held"), 20.0, "match over, order held")
	await wait_seconds(1.0)
	assert_true(_names(client).has("place_change_held"), "the results stay up when the server returns")
	assert_false(_names(client).has("connection_lost"), "returning is not a lost connection")
	assert_true(_names(server).has("match_reset"), "the server went back to the hub")
	assert_eq(_names(server).count("place_changed"), 2, "hub to match, then back to the hub")
	assert_eq(_errors(client), [] as Array[String], "the client logs no errors")
	assert_eq(_errors(server), [] as Array[String], "the server logs no errors")

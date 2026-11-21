## End to end: a real headless dedicated server process, a second client
## process started with --join, and this test as the first client. Both
## clients see each other; this client claims a kill and receives its points.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const PORT: int = 24651
const READY_FILE: String = "user://test_net_match.ready"

var session: GameSession
var _pids: Array[int] = []
var _previous_scene: Node


func _launch(args: Array[String]) -> int:
	var all: PackedStringArray = PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://")])
	all.append_array(PackedStringArray(args))
	var pid: int = OS.create_process(OS.get_executable_path(), all)
	assert_gt(pid, 0, "started %s" % [args])
	_pids.append(pid)
	return pid


func before_all() -> void:
	_remove_ready_file()
	var previous_ready_file: String = OS.get_environment("EU_READY_FILE")
	OS.set_environment("EU_READY_FILE", ProjectSettings.globalize_path(READY_FILE))
	_launch(["res://tests/integration/net_match_server.tscn", "--", "--port=%d" % PORT])
	if previous_ready_file.is_empty():
		OS.unset_environment("EU_READY_FILE")
	else:
		OS.set_environment("EU_READY_FILE", previous_ready_file)
	await wait_until(func() -> bool: return FileAccess.file_exists(READY_FILE), 15.0, "server listening")
	_launch(["--", "--join=127.0.0.1:%d" % PORT])


func after_all() -> void:
	for pid: int in _pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
	_remove_ready_file()


func _remove_ready_file() -> void:
	if FileAccess.file_exists(READY_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(READY_FILE))


func after_each() -> void:
	if is_instance_valid(session):
		get_tree().current_scene = _previous_scene
		session.free()
	Net.leave()


func _remote_players() -> Array[Player]:
	var out: Array[Player] = []
	for player: Player in session.get_players():
		if not player.is_multiplayer_authority():
			out.append(player)
	return out


func _process_events(pid: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for filename: String in DirAccess.get_files_at(Log.DIR):
		if not filename.ends_with("_%d.jsonl" % pid):
			continue
		var contents: String = FileAccess.get_file_as_string(Log.DIR.path_join(filename))
		for line: String in contents.split("\n", false):
			var entry: Variant = JSON.parse_string(line)
			if entry is Dictionary:
				events.append(entry)
	return events


func test_the_server_browser_sees_the_dedicated_server_before_joining() -> void:
	var nonce: PackedByteArray = PackedByteArray([7, 7, 7, 7, 1, 2, 3, 4])
	var socket: PacketPeerUDP = PacketPeerUDP.new()
	socket.bind(0, "127.0.0.1")
	var info: Dictionary = {}
	for i: int in 60:
		if i % 10 == 0:
			ServerInfo.send_queries(socket, nonce, PackedInt32Array([PORT + ServerInfo.PORT_OFFSET]), "127.0.0.1")
		await wait_physics_frames(1)
		while info.is_empty() and socket.get_available_packet_count() > 0:
			info = ServerInfo.parse_reply(socket.get_packet(), nonce)
		if not info.is_empty():
			break
	socket.close()
	assert_eq(info.get("name"), "Dedicated server")
	assert_eq(info.get("protocol"), Build.PROTOCOL_VERSION)
	assert_eq(info.get("max"), Net.MAX_PLAYERS)


func test_wrong_protocol_client_is_refused_and_logs_the_reason() -> void:
	var wrong_protocol: int = Build.PROTOCOL_VERSION + 1
	var pid: int = _launch(["--", "--join=127.0.0.1:%d" % PORT, "--test-protocol=%d" % wrong_protocol])
	var refused: Callable = func() -> bool:
		for entry: Dictionary in _process_events(pid):
			if entry.get("event") == "join_refused":
				return true
		return false
	await wait_until(refused, 15.0, "wrong-version client received its refusal")
	await wait_seconds(0.5)
	assert_true(OS.is_process_running(pid), "the refused client returns to the menu without crashing")
	var refusal: Dictionary = {}
	var errors: Array[String] = []
	for entry: Dictionary in _process_events(pid):
		assert_ne(entry.get("event"), "player_spawned", "incompatible clients never spawn a Player")
		if entry.get("level") == "error":
			errors.append(str(entry.get("data")))
		if entry.get("event") == "join_refused":
			refusal = entry.get("data", {})
	assert_eq(errors, [], "the refused client logs no engine or script errors")
	assert_false(refusal.is_empty(), "the real client logged its refusal")
	assert_eq(refusal.get("reason"), "WRONG_VERSION")
	assert_eq(int(refusal.get("client_protocol", -1)), wrong_protocol)
	assert_eq(int(refusal.get("server_protocol", -1)), Build.PROTOCOL_VERSION)
	assert_true(str(refusal.get("message", "")).begins_with("Cannot join:"), "the reason uses plain words")


func test_two_clients_meet_on_a_dedicated_server() -> void:
	Net.pending_join = "127.0.0.1:%d" % PORT
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	# The match must sit at /root/GameSession on every peer for node paths to match.
	get_tree().root.add_child(session)
	_previous_scene = get_tree().current_scene
	get_tree().current_scene = session
	assert_eq(str(session.get_path()), "/root/GameSession")
	assert_false(Net.is_authority(), "this test is a client")
	var both_in: Callable = func() -> bool: return session.get_players().size() == 2
	await wait_until(both_in, 45.0, "both clients joined")
	var my_id: int = multiplayer.get_unique_id()
	var mine: Player = session.players.find_player(my_id)
	assert_not_null(mine, "the server made a player for this client")
	if mine == null:
		return
	assert_true(mine.is_multiplayer_authority())
	assert_true(mine.camera.current)
	assert_eq(_remote_players().size(), 1, "the other client's player is here too")
	assert_null(session.players.find_player(1), "a dedicated server has no player of its own")
	var follows: Callable = func() -> bool: return session.director.phase != WaveDirector.Phase.IDLE
	await wait_until(follows, 10.0, "the client follows the server's round state")
	assert_ne(session.director.phase, WaveDirector.Phase.IDLE, "the server's round state reached this client")
	var has_zombie: Callable = func() -> bool: return session.spawner.alive_count() > 0
	await wait_until(has_zombie, 30.0, "the server's first wave reached this client")
	for child: Node in session.spawner.get_children():
		var zombie: Zombie = child as Zombie
		if zombie:
			assert_false(zombie.is_physics_processing(), "client zombies only show the server's")
	await _claim_a_kill(mine)
	await wait_until(
		func() -> bool: return session.loot.get_child_count() > 0, 3.0, "real client received personal loot"
	)
	var drop: LootDrop = session.loot.get_child(0) as LootDrop
	assert_not_null(drop)
	if drop:
		assert_eq(drop.player, mine)
		assert_false(drop.item.is_empty())
		mine.global_position = drop.global_position
		drop.interact(mine)
		assert_eq(session.loot.pack.items.size(), 1)


## The --join client starts from the menu in the hub; the server runs the match, so the
## client switches place before any player spawns and ends up in the match.
func test_a_menu_client_joining_a_running_match_switches_from_the_hub() -> void:
	var joiner: int = _pids[1]
	var names: Callable = func() -> Array[String]:
		var out: Array[String] = []
		for entry: Dictionary in _process_events(joiner):
			out.append(str(entry.get("event")))
		return out
	await wait_until(
		func() -> bool: return (names.call() as Array[String]).has("player_spawned"), 45.0, "joiner spawned"
	)
	var events: Array[String] = names.call()
	var switch: int = events.find("join_switches_place")
	assert_gt(switch, -1, "the joiner switched place")
	assert_lt(switch, events.find("player_spawned"), "the switch comes before any player spawns")
	for entry: Dictionary in _process_events(joiner):
		if entry.get("event") == "join_switches_place":
			assert_eq(entry.get("data"), {"from": "hub", "to": "match"})


func _claim_a_kill(mine: Player) -> void:
	await wait_until(
		func() -> bool: return mine.wallet.points == session.economy.rules.starting_points,
		5.0,
		"initial points reached their owner"
	)
	var starting_points: int = mine.wallet.points
	var zombie: Zombie
	for child: Node in session.spawner.get_children():
		if child is Zombie and (child as Zombie).state != Zombie.State.DEAD:
			zombie = child as Zombie
			break
	assert_not_null(zombie)
	if zombie == null:
		return
	await _trace_first_hit(mine, zombie)
	var claims: Node = session.get_node(^"HitClaims")
	var weapon: WeaponData = mine.weapons.current.data
	var zombie_name: StringName = zombie.name
	for shot: int in 10:
		if zombie.state == Zombie.State.DEAD:
			break
		claims.rpc_id(
			1, &"claim_hit", zombie_name, DamageInfo.Zone.BODY, weapon.damage, weapon.id, zombie.global_position
		)
		await wait_seconds(weapon.get_fire_interval() * 1.1)
	assert_eq(zombie.state, Zombie.State.DEAD, "the server accepted this client's hits and synced death")
	var paid: Callable = func() -> bool:
		return mine.wallet.points >= starting_points + session.economy.rules.points_per_kill
	await wait_until(paid, 3.0, "the owning client received its kill points")
	assert_true(paid.call())
	var kill: Dictionary = _server_kill(zombie_name)
	assert_false(kill.is_empty(), "the server log records the authoritative kill")
	assert_eq(int(kill.get("attacker", 0)), mine.net_id, "server credited this client")
	assert_eq(int(kill.get("points", 0)), mine.wallet.points, "client HUD total matches server payout")


func _trace_first_hit(mine: Player, zombie: Zombie) -> void:
	await wait_physics_frames(2)
	var weapon: Weapon = mine.weapons.current
	var body: HitZone = zombie.get_node(^"HitZones/Body") as HitZone
	var origin: Vector3 = body.global_position + body.global_basis.z * 0.30
	var points_before: int = mine.wallet.points
	watch_signals(weapon)
	weapon._trace(origin, -body.global_basis.z)
	var landed: Array = get_signal_parameters(weapon, "hit_landed")
	assert_false(landed[0], "a client hit is never a kill until the server says so")
	assert_false((landed[1] as DamageInfo).is_headshot(), "body hit")
	assert_eq(zombie.health.current, zombie.health.max_health, "client trace never applies local damage")
	await wait_until(
		func() -> bool: return mine.wallet.points == points_before + session.economy.rules.points_per_hit,
		3.0,
		"the server applied the client's weapon trace and paid the hit"
	)
	assert_eq(mine.wallet.points, points_before + session.economy.rules.points_per_hit)


func _server_kill(zombie_name: StringName) -> Dictionary:
	var suffix: String = "_%d.jsonl" % _pids[0]
	for filename: String in DirAccess.get_files_at(Log.DIR):
		if not filename.ends_with(suffix):
			continue
		var file: FileAccess = FileAccess.open(Log.DIR.path_join(filename), FileAccess.READ)
		while file and not file.eof_reached():
			var line: Variant = JSON.parse_string(file.get_line())
			if line is Dictionary and line.get("event") == "test_enemy_killed":
				var data: Dictionary = line.get("data", {})
				if data.get("zombie") == String(zombie_name):
					return data
	return {}

## End to end: a real headless dedicated server process, a second client
## process started with --join, and this test as the first client. Both
## clients see each other; this client claims a kill and receives its points.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const PORT: int = 24651

var session: GameSession
var _pids: Array[int] = []
var _previous_scene: Node


func _launch(args: Array[String]) -> void:
	var all: PackedStringArray = PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://")])
	all.append_array(PackedStringArray(args))
	var pid: int = OS.create_process(OS.get_executable_path(), all)
	assert_gt(pid, 0, "started %s" % [args])
	_pids.append(pid)


func before_all() -> void:
	_launch(["res://tests/integration/net_match_server.tscn", "--", "--port=%d" % PORT])
	_launch(["--", "--join=127.0.0.1:%d" % PORT])


func after_all() -> void:
	for pid: int in _pids:
		OS.kill(pid)


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
	assert_eq(session.director.phase, WaveDirector.Phase.IDLE, "clients never run the waves")
	var has_zombie: Callable = func() -> bool: return session.spawner.alive_count() > 0
	await wait_until(has_zombie, 30.0, "the server's first wave reached this client")
	for child: Node in session.spawner.get_children():
		var zombie: Zombie = child as Zombie
		if zombie:
			assert_false(zombie.is_physics_processing(), "client zombies only show the server's")
	await _claim_a_kill(mine)


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
	assert_signal_emitted_with_parameters(weapon, "hit_landed", [false, false])
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

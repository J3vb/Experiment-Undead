## End to end: a real headless dedicated server process, a second client
## process started with --join, and this test as the first client. Both
## clients end up in the same match and see each other's player.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const PORT: int = 24651

var session: GameSession
var _pids: Array[int] = []


func _launch(args: Array[String]) -> void:
	var all: PackedStringArray = PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://")])
	all.append_array(PackedStringArray(args))
	var pid: int = OS.create_process(OS.get_executable_path(), all)
	assert_gt(pid, 0, "started %s" % [args])
	_pids.append(pid)


func before_all() -> void:
	_launch(["res://systems/net/dedicated_server.tscn", "--", "--port=%d" % PORT])
	_launch(["--", "--join=127.0.0.1:%d" % PORT])


func after_all() -> void:
	for pid: int in _pids:
		OS.kill(pid)


func after_each() -> void:
	if is_instance_valid(session):
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

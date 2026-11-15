## Two ENet peers run real GameSessions on an empty map: squad wipes and
## disconnects end only on the server, and both sides receive the same results.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const PORT: int = 24645

var server_root: Node
var client_root: Node
var server: GameSession
var client: GameSession
var late_root: Node


func _make_side(side_name: String) -> Node:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	return root


func _make_session(root: Node) -> GameSession:
	var map: Level = Level.new()
	map.name = "Level"
	var scene: PackedScene = PackedScene.new()
	scene.pack(map)
	map.free()
	var session: GameSession = SESSION.instantiate() as GameSession
	session.level_scene = scene
	session.profile_id = &""
	session.rng_seed = 31
	session.restart_delay = 0.01
	session.wave_rules = session.wave_rules.duplicate(true) as WaveRules
	session.wave_rules.first_round_delay = 10000.0
	root.add_child(session)
	return session


func before_each() -> void:
	server_root = _make_side("Server")
	client_root = _make_side("Client")
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT, 2), OK)
	server_root.multiplayer.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client_root.multiplayer.multiplayer_peer = client_peer
	client = _make_session(client_root)
	server = _make_session(server_root)
	var joined: Callable = func() -> bool: return server.get_players().size() == 2 and client.get_players().size() == 2
	await wait_until(joined, 5.0, "both sessions have both players")
	for session: GameSession in [server, client]:
		for player: Player in session.get_players():
			player.set_physics_process(false)


func after_each() -> void:
	var roots: Array[Node] = [client_root, server_root]
	if is_instance_valid(late_root):
		roots.push_front(late_root)
	for root: Node in roots:
		var path: NodePath = root.get_path()
		root.multiplayer.multiplayer_peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		root.free()
		get_tree().set_multiplayer(null, path)
	get_tree().paused = false


func _down(player: Player) -> void:
	player.health.take_damage(DamageInfo.create(1000.0, null))


func test_one_downed_player_keeps_the_match_running() -> void:
	_down(server.players.find_player(1))
	assert_false(server.is_over, "the teammate can still revive")
	assert_false(client.is_over, "clients do not independently end the match")
	assert_eq(server.get_players().size(), 2, "other session players are excluded")


func test_squad_wipe_freezes_both_peers_and_shows_identical_results() -> void:
	server.director.round_number = 4
	server._kills = 7
	server._headshots = 3
	server.players.find_player(1).wallet.set_points(1234)
	_down(server.players.find_player(1))
	_down(server.players.find_player(client.multiplayer.get_unique_id()))
	assert_true(server.is_over)
	await wait_until(func() -> bool: return client.is_over, 3.0, "server ended the client's match")
	assert_eq(client._match_stats, server._match_stats)
	assert_eq(client._match_stats["round"], 4)
	assert_eq(client._match_stats["kills"], 7)
	assert_eq(client._match_stats["headshots"], 3)
	assert_eq(client._match_stats["points"], 1234)
	assert_eq(server.level.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(client.level.process_mode, Node.PROCESS_MODE_DISABLED)
	await wait_until(func() -> bool: return client.hud.results_screen.visible, 3.0, "client sees results")
	assert_true(server.hud.results_screen.visible)


func test_leaving_standing_teammate_does_not_prevent_game_over() -> void:
	_down(server.players.find_player(1))
	assert_false(server.is_over)
	client.level.process_mode = Node.PROCESS_MODE_DISABLED
	client_root.multiplayer.multiplayer_peer.close()
	client_root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	await wait_until(func() -> bool: return server.is_over, 5.0, "only the downed host remains")
	assert_eq(server.get_players().size(), 1)


func test_client_cannot_end_the_match_or_decide_a_wipe() -> void:
	client._end_match(false)
	client.check_squad()
	assert_false(client.is_over)
	assert_false(server.is_over)


func test_empty_dedicated_server_keeps_waiting() -> void:
	for player: Player in server.get_players():
		player.session = null
	server.check_squad()
	assert_false(server.is_over)


func test_dead_and_downed_members_also_end_the_match() -> void:
	var host: Player = server.players.find_player(1)
	_down(host)
	host.state_sync._physics_process(30.1)
	assert_true(host.is_dead)
	assert_false(server.is_over, "the standing teammate remains")
	_down(server.players.find_player(client.multiplayer.get_unique_id()))
	assert_true(server.is_over, "dead and downed leaves nobody standing")


func test_late_joiner_receives_an_ended_match() -> void:
	_down(server.players.find_player(1))
	_down(server.players.find_player(client.multiplayer.get_unique_id()))
	assert_true(server.is_over)
	late_root = _make_side("LateClient")
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", PORT), OK)
	late_root.multiplayer.multiplayer_peer = peer
	var late_session: GameSession = _make_session(late_root)
	await wait_until(func() -> bool: return late_session.is_over, 5.0, "late join receives match results")
	assert_eq(late_session._match_stats, server._match_stats)
	assert_eq(late_session.level.process_mode, Node.PROCESS_MODE_DISABLED)

## Real owner-targeted XP RPCs bank through GameSession into isolated local character files.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const BANK_SESSION: Script = preload("res://tests/unit/run_end_session.gd")
const IDS: Array[StringName] = [&"test_run_owner_a", &"test_run_owner_b", &"test_run_dedicated"]

var server_root: Node
var clients: Array[Node] = []
var sessions: Array[GameSession] = []
var peer_ids: Array[int] = []
var _port: int


func _make_side(side_name: String) -> Node:
	var root: Node = TwoPeers.make_side(self, side_name)
	var session: GameSession = SESSION.instantiate() as GameSession
	session.set_script(BANK_SESSION)
	session.profile_id = &""
	session.name = "GameSession"
	root.add_child(session)
	return root


func before_each() -> void:
	_port = TwoPeers.next_port()
	_remove_profiles()
	server_root = _make_side("GrantServer")
	assert_eq(TwoPeers.host(server_root, _port, 2), OK)
	for index: int in range(2):
		var root: Node = _make_side("GrantClient%d" % index)
		assert_eq(TwoPeers.join(root, _port), OK)
		clients.append(root)
	await wait_until(func() -> bool: return server_root.multiplayer.get_peers().size() == 2, 5.0, "two clients")
	for client: Node in clients:
		peer_ids.append(client.multiplayer.get_unique_id())
	for root: Node in [server_root, clients[0], clients[1]]:
		for owner_id: int in peer_ids:
			_add_player(root, owner_id)
	for index: int in range(2):
		var session: GameSession = clients[index].get_node("GameSession") as GameSession
		session.profile_player = _player(clients[index], peer_ids[index])
		session.loot.player = session.profile_player
		session.profile = CharacterProfile.load_or_create(IDS[index])
		session.profile.total_xp = 100 * (index + 1)
		assert_eq(session.profile.save(), OK)
		session.progression.set_start_total(session.profile_player, session.profile.total_xp)
		session.progression.run_xp_finalized.connect(session.match_end.bank_run_xp)
		watch_signals(session.progression)
		sessions.append(session)


func after_each() -> void:
	for root: Node in [clients[1], clients[0], server_root]:
		TwoPeers.close_side(root)
	clients.clear()
	sessions.clear()
	peer_ids.clear()
	_remove_profiles()


func _add_player(root: Node, owner_id: int) -> void:
	var player: Player = PLAYER.instantiate() as Player
	player.get_node("PoseSync").free()
	player.name = str(owner_id)
	player.net_id = owner_id
	player.set_multiplayer_authority(owner_id)
	root.add_child(player)
	player.set_physics_process(false)


func _service(root: Node) -> ProgressionService:
	return root.get_node("GameSession/Progression") as ProgressionService


func _player(root: Node, owner_id: int) -> Player:
	return root.get_node(str(owner_id)) as Player


func _read_xp(index: int) -> int:
	return CharacterProfile.load_or_create(IDS[index]).total_xp


func _remove_profiles() -> void:
	for id: StringName in IDS:
		var path: String = CharacterProfile.directory() + String(id) + ".json"
		for file: String in [path, path + ".tmp"]:
			if FileAccess.file_exists(file):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


func test_final_grant_reaches_only_owner_and_banks_once() -> void:
	sessions[0].loot.pack.add({"uid": "personal-a", "base": "vest_light", "rar": "rare"})
	sessions[1].loot.pack.add({"uid": "personal-b", "base": "charm_coin", "rar": "common"})
	var service: ProgressionService = _service(server_root)
	var owner: Player = _player(server_root, peer_ids[0])
	service.add_xp(owner, 75)
	var server_session: GameSession = server_root.get_node("GameSession") as GameSession
	server_session.has_local_player = false
	server_session.match_end.bank_run_xp()
	server_session.match_end.bank_run_xp()
	assert_true(service._pending_grants.has(peer_ids[0]))
	await service.wait_for_run_grants()
	assert_true(service._pending_grants.is_empty(), "owner acknowledges after saving")
	await wait_until(func() -> bool: return _read_xp(0) == 175, 5.0, "owner profile banked")
	assert_eq(CharacterProfile.load_or_create(IDS[0]).stash[0].get("uid"), "personal-a")
	assert_eq(CharacterProfile.load_or_create(IDS[1]).stash[0].get("uid"), "personal-b")
	assert_eq(_read_xp(0), 175)
	assert_eq(_read_xp(1), 200, "another client's character is untouched")
	assert_eq(_service(clients[0]).get_total_xp(_player(clients[0], peer_ids[0])), 175, "HUD includes saved XP")
	assert_eq(_service(clients[0]).get_xp(_player(clients[0], peer_ids[1])), 0)
	assert_eq(_service(clients[1]).get_xp(_player(clients[1], peer_ids[0])), 0)
	assert_signal_emit_count(_service(clients[0]), "run_xp_finalized", 1)
	assert_signal_emit_count(_service(clients[1]), "run_xp_finalized", 1)
	sessions[0].match_end.bank_run_xp()
	assert_eq(_read_xp(0), 175, "leaving after the grant does not bank twice")


func test_dedicated_server_never_saves_a_character() -> void:
	var dedicated: GameSession = server_root.get_node("GameSession") as GameSession
	dedicated.has_local_player = false
	dedicated.profile = CharacterProfile.load_or_create(IDS[2])
	dedicated.profile_player = _player(server_root, peer_ids[0])
	dedicated.progression.add_xp(dedicated.profile_player, 75)
	dedicated.match_end.bank_run_xp()
	assert_false(FileAccess.file_exists(CharacterProfile.directory() + String(IDS[2]) + ".json"))


func test_different_players_bank_their_own_totals() -> void:
	var service: ProgressionService = _service(server_root)
	service.add_xp(_player(server_root, peer_ids[0]), 25)
	service.add_xp(_player(server_root, peer_ids[1]), 90)
	service.finish_run(_player(server_root, peer_ids[0]))
	service.finish_run(_player(server_root, peer_ids[1]))
	await wait_until(func() -> bool: return _read_xp(0) == 125 and _read_xp(1) == 290, 5.0, "both owners saved")
	assert_eq(_read_xp(0), 125)
	assert_eq(_read_xp(1), 290)


func test_owner_snapshot_announces_each_new_level_once() -> void:
	var service: ProgressionService = _service(server_root)
	var owner: Player = _player(server_root, peer_ids[0])
	var local_service: ProgressionService = _service(clients[0])
	var local_player: Player = _player(clients[0], peer_ids[0])
	sessions[0].profile.total_xp = 450
	assert_eq(sessions[0].profile.save(), OK)
	local_service.set_start_total(local_player, 450)
	service.add_xp(owner, 3200)
	# Server events fire synchronously; only the subsequent client RPC is observed.
	watch_signals(Events)
	await wait_until(func() -> bool: return local_service.get_level(local_player) == 4, 5.0, "owner reached level four")
	assert_signal_emit_count(Events, "player_leveled_up", 3)
	for index: int in range(3):
		assert_eq(get_signal_parameters(Events, "player_leveled_up", index), [local_player, index + 2])
	service._receive_run_xp.rpc_id(peer_ids[0], 3200, false)
	service.finish_run(owner)
	await service.wait_for_run_grants()
	assert_signal_emit_count(Events, "player_leveled_up", 3, "duplicate and final totals do not repeat level-ups")
	assert_eq(_read_xp(0), 3650)


func test_disconnect_banks_last_received_xp_without_final_grant() -> void:
	var local_player: Player = _player(clients[0], peer_ids[0])
	var local_service: ProgressionService = _service(clients[0])
	_service(server_root).add_xp(_player(server_root, peer_ids[0]), 60)
	await wait_until(func() -> bool: return local_service.get_xp(local_player) == 60, 5.0, "live owner XP")
	assert_eq(_read_xp(0), 100, "live updates do not bank the unfinished run")
	clients[0].multiplayer.multiplayer_peer.close()
	sessions[0].match_end.bank_run_xp()
	assert_eq(_read_xp(0), 160)
	assert_signal_not_emitted(local_service, "run_xp_finalized")
	assert_eq(_read_xp(1), 200)


func test_disconnected_owner_does_not_hold_the_server_open() -> void:
	var service: ProgressionService = _service(server_root)
	service.finish_run(_player(server_root, peer_ids[0]))
	assert_true(service._pending_grants.has(peer_ids[0]))
	clients[0].multiplayer.multiplayer_peer.close()
	await service.wait_for_run_grants()
	assert_true(service._pending_grants.is_empty(), "disconnect clears the unacknowledged final grant")


func test_client_cannot_author_or_finalize_xp() -> void:
	var local_service: ProgressionService = _service(clients[0])
	var local_player: Player = _player(clients[0], peer_ids[0])
	local_service.add_xp(local_player, 5000)
	local_service.finish_run(local_player)
	local_service._receive_run_xp(5000, true)
	var other_player: Player = _player(clients[0], peer_ids[1])
	local_service.set_start_total(other_player, 5000)
	assert_eq(local_service.get_xp(local_player), 0)
	assert_eq(local_service.get_total_xp(other_player), 0, "a client cannot set another player's starting total")
	assert_eq(_read_xp(0), 100)
	assert_signal_not_emitted(local_service, "run_xp_finalized")

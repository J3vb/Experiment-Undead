## Real ENet peers exercise PlayerStateSync health, downed/dead states and revive outcomes.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const PORT: int = 24644

var server_root: Node
var client_root: Node
var server_spawner: PlayerSpawner
var client_spawner: PlayerSpawner
var client_id: int


func _make_side(side_name: String) -> Node:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var world: Node3D = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var spawner: PlayerSpawner = PlayerSpawner.new()
	spawner.name = "PlayerSpawner"
	spawner.player_scene = PLAYER
	root.add_child(spawner)
	return root


func before_each() -> void:
	server_root = _make_side("Server")
	client_root = _make_side("Client")
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT, 2), OK)
	server_root.multiplayer.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client_root.multiplayer.multiplayer_peer = client_peer
	server_spawner = server_root.get_node("PlayerSpawner") as PlayerSpawner
	client_spawner = client_root.get_node("PlayerSpawner") as PlayerSpawner
	var spawn_point: Transform3D = Transform3D(Basis(), Vector3(5, 0, 5))
	client_spawner.setup(client_root.get_node("World") as Node3D, spawn_point)
	server_spawner.setup(server_root.get_node("World") as Node3D, spawn_point)
	await wait_until(
		func() -> bool: return _players(server_root).size() == 2 and _players(client_root).size() == 2,
		5.0,
		"both peers see the squad"
	)
	client_id = client_root.multiplayer.get_unique_id()
	for root: Node in [server_root, client_root]:
		for player: Player in _players(root):
			player.set_physics_process(false)
			player.health.set_process(false)
			player.health.regen_delay = 0.0


func after_each() -> void:
	for root: Node in [client_root, server_root]:
		var path: NodePath = root.get_path()
		root.multiplayer.multiplayer_peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		for player: Player in _players(root):
			player.free()
		root.free()
		get_tree().set_multiplayer(null, path)


func _players(root: Node) -> Array[Player]:
	var out: Array[Player] = []
	for child: Node in root.get_node("World").get_children():
		if child is Player:
			out.append(child as Player)
	return out


func _server(peer_id: int = 1) -> Player:
	return server_spawner.find_player(peer_id)


func _client(peer_id: int = 1) -> Player:
	return client_spawner.find_player(peer_id)


func _down_host() -> void:
	_server().take_damage(DamageInfo.create(1000.0, null))
	await wait_until(func() -> bool: return _client().is_downed, 3.0, "downed state reached client")


func _hold_interact(player: Player, held: bool) -> void:
	player.revive.set_held(held)


func _start_revive() -> void:
	_hold_interact(_client(client_id), true)
	await wait_until(
		func() -> bool: return _server(client_id).revive._active == _server(), 3.0, "server accepted revive"
	)


func test_server_damage_reaches_owning_clients_health_and_event() -> void:
	var target: Player = _server(client_id)
	var copy: Player = _client(client_id)
	watch_signals(Events)
	target.take_damage(DamageInfo.create(35.0, null))
	await wait_until(func() -> bool: return copy.health.current == 65.0, 3.0, "health synced")
	assert_eq(target.health.current, 65.0)
	assert_eq(copy.health.max_health, 100.0)
	assert_signal_emitted_with_parameters(Events, "player_health_changed", [copy, 65.0, 100.0])
	assert_true(copy.health.current < copy.health.max_health, "the HUD observes the replicated pool")


func test_client_damage_and_serum_requests_do_not_change_health() -> void:
	var mine: Player = _client(client_id)
	mine.take_damage(DamageInfo.create(40.0, null))
	mine.add_serum(Content.get_item(&"serums", &"ironhide") as SerumData)
	await wait_physics_frames(3)
	assert_eq(mine.health.current, 100.0)
	assert_eq(mine.health.max_health, 100.0)
	assert_eq(_server(client_id).health.current, 100.0)
	assert_eq(_server(client_id).serums.size(), 0)


func test_downed_and_revived_states_reach_client() -> void:
	await _down_host()
	assert_true(_server().is_downed)
	assert_false(_server().is_dead, "downed players can still be revived")
	assert_false(_client().is_alive(), "zombies ignore downed targets")
	assert_eq(_client().health.current, 0.0)
	watch_signals(Events)
	_server().state_sync.revive_player()
	await wait_until(func() -> bool: return _client().is_alive(), 3.0, "revive reached client")
	assert_false(_client().is_downed)
	assert_false(_client().is_dead)
	assert_eq(_client().health.current, 100.0)
	assert_signal_emitted_with_parameters(Events, "player_revived", [_client()])


func test_hold_completes_after_three_server_seconds_and_pays_only_reviver() -> void:
	await _down_host()
	var before: int = _server(client_id).wallet.points
	var target_points: int = _server().wallet.points
	await _start_revive()
	_server(client_id).revive._physics_process(2.0)
	assert_true(_server().is_downed, "a client cannot skip the hold duration")
	_server(client_id).revive._physics_process(1.0)
	await wait_until(func() -> bool: return not _client().is_downed, 3.0, "revived on both peers")
	await wait_until(func() -> bool: return _client(client_id).wallet.points == before + 50, 3.0, "reward synced")
	assert_eq(_server(client_id).wallet.points, before + 50)
	assert_eq(_server().wallet.points, target_points)
	assert_eq(_client().wallet.points, target_points)


func test_revive_is_refused_out_of_range() -> void:
	await _down_host()
	_client(client_id).position = Vector3(20, 0, 5)
	await wait_until(func() -> bool: return _server(client_id).position.x == 20.0, 3.0, "reviver moved away")
	_client(client_id).revive._request.rpc_id(1, 1)
	await wait_physics_frames(5)
	assert_null(_server(client_id).revive._active, "server refuses invalid intent")
	_server(client_id).revive._physics_process(3.0)
	assert_true(_server().is_downed)
	assert_eq(_server(client_id).wallet.points, 0)


func test_downed_reviver_is_refused() -> void:
	await _down_host()
	_server(client_id).take_damage(DamageInfo.create(1000.0, null))
	await wait_until(func() -> bool: return _client(client_id).is_downed, 3.0, "reviver is downed")
	_client(client_id).revive._request.rpc_id(1, 1)
	await wait_physics_frames(5)
	assert_null(_server(client_id).revive._active, "server refuses invalid intent")
	_server(client_id).revive._physics_process(3.0)
	assert_true(_server().is_downed)
	assert_eq(_server(client_id).wallet.points, 0)


func test_moving_out_of_range_cancels_an_existing_hold() -> void:
	await _down_host()
	await _start_revive()
	_server(client_id).revive._physics_process(1.0)
	_client(client_id).position = Vector3(20, 0, 5)
	await wait_until(func() -> bool: return _server(client_id).position.x == 20.0, 3.0, "reviver moved away")
	_server(client_id).revive._physics_process(3.0)
	assert_true(_server().is_downed)
	assert_eq(_server(client_id).wallet.points, 0)


func test_releasing_interact_cancels_an_existing_hold() -> void:
	await _down_host()
	await _start_revive()
	_server(client_id).revive._physics_process(1.0)
	_hold_interact(_client(client_id), false)
	await wait_until(func() -> bool: return _server(client_id).revive._active == null, 3.0, "release reached server")
	_server(client_id).revive._physics_process(3.0)
	assert_true(_server().is_downed)
	assert_eq(_server(client_id).wallet.points, 0)


func test_bleed_out_turns_downed_into_hidden_noncolliding_dead_player() -> void:
	await _down_host()
	_server().state_sync._physics_process(29.0)
	assert_true(_server().is_downed)
	assert_false(_server().is_dead)
	_server().state_sync._physics_process(1.0)
	await wait_until(func() -> bool: return _client().is_dead, 3.0, "death reached client")
	assert_false(_client().is_downed)
	assert_false(_client().visible)
	assert_eq(_client().collision_layer, 0)
	assert_eq(_client().collision_mask, 0)


func test_dead_player_respawns_on_next_round_with_start_pistol() -> void:
	var spawn_point: Vector3 = _server(client_id).position
	_server(client_id).take_damage(DamageInfo.create(1000.0, null))
	_server(client_id).state_sync._physics_process(30.0)
	await wait_until(func() -> bool: return _client(client_id).is_dead, 3.0, "owner sees death")
	_client(client_id).position = Vector3(30, 0, 5)
	await wait_until(func() -> bool: return _server(client_id).position.x == 30.0, 3.0, "old pose reached server")
	Events.round_started.emit(2, 8)
	await wait_until(func() -> bool: return _client(client_id).is_alive(), 3.0, "next round respawn")
	assert_true(_client(client_id).visible)
	assert_ne(_client(client_id).collision_layer, 0)
	assert_true(_client(client_id).position.is_equal_approx(spawn_point))
	assert_eq(_client(client_id).weapons.weapons.size(), 1)
	assert_eq(_client(client_id).weapons.current.data.id, &"pistol_service")


func test_server_serum_affects_only_that_players_health_on_both_peers() -> void:
	_server(client_id).add_serum(Content.get_item(&"serums", &"ironhide") as SerumData)
	await wait_until(
		func() -> bool: return _client(client_id).health.max_health == 250.0, 3.0, "buyer max health synced"
	)
	assert_eq(_client(client_id).health.current, 250.0)
	assert_eq(_server().health.max_health, 100.0)
	assert_eq(_client().health.max_health, 100.0)
	assert_eq(_server().health.current, 100.0)
	assert_eq(_client().health.current, 100.0)


func test_getting_downed_cancels_an_existing_hold() -> void:
	await _down_host()
	await _start_revive()
	_server(client_id).revive._physics_process(1.0)
	_server(client_id).take_damage(DamageInfo.create(1000.0, null))
	_server(client_id).revive._physics_process(3.0)
	assert_true(_server().is_downed)
	assert_null(_server(client_id).revive._active)
	assert_eq(_server(client_id).wallet.points, 0)


func test_dead_owner_spectates_a_teammate_on_its_own_peer() -> void:
	_server(client_id).take_damage(DamageInfo.create(1000.0, null))
	_server(client_id).state_sync._physics_process(30.0)
	await wait_until(func() -> bool: return _client(client_id).is_dead, 3.0, "owner sees death")
	_client(client_id).state_sync._physics_process(0.0)
	assert_true(_client().camera.current, "the surviving teammate supplies the spectating camera")
	assert_false(_client(client_id).camera.current)


func test_respawn_then_second_death_restores_spectating() -> void:
	_server(client_id).take_damage(DamageInfo.create(1000.0, null))
	_server(client_id).state_sync._physics_process(30.0)
	await wait_until(func() -> bool: return _client(client_id).is_dead, 3.0, "first death synced")
	_client(client_id).state_sync._physics_process(0.0)
	assert_true(_client().camera.current)
	Events.round_started.emit(2, 8)
	await wait_until(func() -> bool: return _client(client_id).is_alive(), 3.0, "respawn synced")
	assert_true(_client(client_id).camera.current)
	_server(client_id).take_damage(DamageInfo.create(1000.0, null))
	_server(client_id).state_sync._physics_process(30.0)
	await wait_until(func() -> bool: return _client(client_id).is_dead, 3.0, "second death synced")
	_client(client_id).state_sync._physics_process(0.0)
	assert_true(_client().camera.current, "cached first spectating target must be selected again")
	assert_false(_client(client_id).camera.current)


func _remove_client() -> void:
	client_root.multiplayer.multiplayer_peer.close()
	await wait_until(func() -> bool: return _players(server_root).size() == 1, 3.0, "client left")
	var path: NodePath = client_root.get_path()
	for player: Player in _players(client_root):
		player.free()
	client_root.free()
	get_tree().set_multiplayer(null, path)


func _join_again() -> void:
	client_root = _make_side("Client")
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", PORT), OK)
	client_root.multiplayer.multiplayer_peer = peer
	client_spawner = client_root.get_node("PlayerSpawner") as PlayerSpawner
	client_spawner.setup(client_root.get_node("World") as Node3D, Transform3D.IDENTITY)
	await wait_until(func() -> bool: return _players(client_root).size() == 2, 3.0, "late join sees squad")
	client_id = client_root.multiplayer.get_unique_id()
	for player: Player in _players(client_root):
		player.set_physics_process(false)
		player.health.regen_delay = 0.0


func test_late_join_gets_existing_downed_state_and_health() -> void:
	await _remove_client()
	_server().take_damage(DamageInfo.create(1000.0, null))
	await _join_again()
	await wait_until(func() -> bool: return _client().is_downed, 3.0, "late join receives current state")
	assert_eq(_client().health.current, 0.0)
	assert_false(_client().is_dead)
	assert_false(_client().is_alive())


func test_late_join_gets_existing_dead_state() -> void:
	await _remove_client()
	_server().take_damage(DamageInfo.create(1000.0, null))
	_server().state_sync._physics_process(30.0)
	await _join_again()
	await wait_until(func() -> bool: return _client().is_dead, 3.0, "late join receives existing death")
	assert_eq(_client().health.current, 0.0)
	assert_false(_client().visible)
	assert_eq(_client().collision_layer, 0)


func test_revive_restores_full_inventory_after_temporary_sidearm() -> void:
	var mine: Player = _client(client_id)
	var rifle: Weapon = mine.weapons.give(Content.weapon(&"rifle_ar"))
	var shotgun: Weapon = mine.weapons.give(Content.weapon(&"brenner_trench"))
	var inventory: Array[Weapon] = [rifle, shotgun]
	_server(client_id).take_damage(DamageInfo.create(1000.0, null))
	await wait_until(func() -> bool: return mine.is_downed, 3.0, "owner gets downed sidearm")
	assert_eq(mine.weapons.current.data.id, &"pistol_service")
	assert_true(mine.weapons.weapons.has(rifle))
	assert_true(mine.weapons.weapons.has(shotgun))
	assert_eq(mine.weapons.max_slots, 2, "the temporary slot does not raise inventory capacity")
	_server(client_id).state_sync.revive_player()
	await wait_until(func() -> bool: return mine.is_alive(), 3.0, "owner revived")
	assert_eq(mine.weapons.weapons, inventory, "reviving preserves purchased guns and their live state")
	assert_eq(mine.weapons.current, shotgun, "the previous equipped gun is restored")

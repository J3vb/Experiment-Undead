## Real ENet peers relay one cosmetic shot, with no owner echo or gameplay changes.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const PORT: int = 24681

var _roots: Array[Node] = []
var _sessions: Array[GameSession] = []


func _make_side(side_name: String) -> Node:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var world: Node3D = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var session: GameSession = GameSession.new()
	session.rng.seed = 7
	_sessions.append(session)
	var shots: RemoteShots = RemoteShots.new()
	shots.name = "RemoteShots"
	shots.session = session
	session.remote_shots = shots
	root.add_child(shots)
	var spawner: PlayerSpawner = PlayerSpawner.new()
	spawner.name = "PlayerSpawner"
	spawner.player_scene = PLAYER
	session.players = spawner
	spawner.player_added.connect(
		func(player: Player) -> void:
			player.spawn(session, [Content.weapon(&"brenner_trench")])
			player.set_physics_process(false)
			shots.watch_player(player)
	)
	root.add_child(spawner)
	_roots.append(root)
	return root


func before_each() -> void:
	var server: Node = _make_side("Server")
	var client: Node = _make_side("Client")
	var observer: Node = _make_side("Observer")
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT, 3), OK)
	server.multiplayer.multiplayer_peer = server_peer
	for root: Node in [client, observer]:
		var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
		assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
		root.multiplayer.multiplayer_peer = client_peer
	for index: int in [1, 2, 0]:
		var root: Node = _roots[index]
		var spawner: PlayerSpawner = _sessions[index].players
		spawner.setup(root.get_node("World") as Node3D, Transform3D.IDENTITY)
	await wait_until(
		func() -> bool:
			return (
				_roots[0].get_node("World").get_child_count() == 3
				and _roots[1].get_node("World").get_child_count() == 3
				and _roots[2].get_node("World").get_child_count() == 3
			),
		5.0,
		"three peers see three players"
	)


func after_each() -> void:
	_roots.reverse()
	for root: Node in _roots:
		var path: NodePath = root.get_path()
		root.multiplayer.multiplayer_peer.close()
		root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		root.free()
		get_tree().set_multiplayer(null, path)
	for session: GameSession in _sessions:
		session.free()
	_roots.clear()
	_sessions.clear()


func _effects(side: int, peer_id: int) -> RemoteShotEffects:
	return _sessions[side].players.find_player(peer_id).get_node("ShotEffects") as RemoteShotEffects


func test_client_shot_reaches_host_and_other_client_with_all_missed_pellets() -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var shooter: Player = _sessions[1].players.find_player(peer_id)
	var server_copy: Player = _sessions[0].players.find_player(peer_id)
	var host_effects: RemoteShotEffects = _effects(0, peer_id)
	var other_effects: RemoteShotEffects = _effects(2, peer_id)
	var weapon: Weapon = shooter.weapons.current
	var health_before: float = server_copy.health.current
	weapon.fire()
	await wait_until(
		func() -> bool: return host_effects.has_node("Tracers") and other_effects.has_node("Tracers"),
		3.0,
		"client shot relayed through server"
	)
	assert_false(shooter.has_node("ShotEffects"), "owner only plays its original local effects")
	_assert_shot(host_effects, weapon.data)
	_assert_shot(other_effects, weapon.data)
	assert_eq(server_copy.health.current, health_before, "cosmetics do no damage")
	assert_eq(server_copy.wallet.points, 0, "cosmetics award no points")
	assert_eq(server_copy.weapons.current.instance.ammo_in_mag, weapon.data.magazine_size)
	assert_eq(weapon.instance.ammo_in_mag, weapon.data.magazine_size - 1, "one shell for all pellets")
	assert_true(_sessions[1].remote_shots._points.is_empty(), "shot flushes its endpoints")


func test_host_shot_reaches_both_clients_without_echo() -> void:
	var host: Player = _sessions[0].players.find_player(1)
	var client_effects: RemoteShotEffects = _effects(1, 1)
	var other_effects: RemoteShotEffects = _effects(2, 1)
	host.weapons.current.fire()
	await wait_until(
		func() -> bool: return client_effects.has_node("Tracers") and other_effects.has_node("Tracers"),
		3.0,
		"host shot reaches clients"
	)
	_assert_shot(client_effects, host.weapons.current.data)
	_assert_shot(other_effects, host.weapons.current.data)
	assert_false(host.has_node("ShotEffects"))


func test_replacement_weapon_is_watched() -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var shooter: Player = _sessions[1].players.find_player(peer_id)
	var effects: RemoteShotEffects = _effects(2, peer_id)
	var weapon: Weapon = shooter.weapons.replace_current(Content.weapon(&"rifle_ar"))
	weapon.fire()
	await wait_until(func() -> bool: return effects.has_node("Tracers"), 3.0, "replacement gun shot relayed")
	_assert_shot(effects, weapon.data)


func test_bad_cosmetic_packets_are_dropped() -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var shots: RemoteShots = _sessions[1].remote_shots
	shots.shot.rpc_id(1, &"missing", Vector3.ZERO, PackedVector3Array([Vector3.ONE]))
	shots.shot.rpc_id(1, &"brenner_trench", Vector3.ZERO, PackedVector3Array([Vector3.ONE]))
	await wait_physics_frames(8)
	assert_false(_effects(0, peer_id).has_node("Tracers"))
	assert_false(_effects(2, peer_id).has_node("Tracers"))


func test_coachman_alt_relays_twenty_pellets_in_one_packet() -> void:
	await _check_double_barrel_alt(&"coachman_2b")


func test_grubber_alt_relays_sixteen_pellets_in_one_packet() -> void:
	await _check_double_barrel_alt(&"grubber_sawnoff")


func _check_double_barrel_alt(weapon_id: StringName) -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var shooter: Player = _sessions[1].players.find_player(peer_id)
	var weapon: Weapon = shooter.weapons.replace_current(Content.weapon(weapon_id))
	shooter.last_frame.buttons = InputFrame.ALT_FIRE
	weapon.tick(1.0 / 60.0)
	await wait_until(
		func() -> bool: return _effects(0, peer_id).has_node("Tracers") and _effects(2, peer_id).has_node("Tracers"),
		3.0,
		"both-barrel packet reaches host and observer"
	)
	assert_eq(weapon.instance.ammo_in_mag, 0)
	assert_false(shooter.has_node("ShotEffects"), "the owner does not receive an effect echo")
	_assert_shot(_effects(0, peer_id), weapon.data, weapon.data.pellets * 2)
	_assert_shot(_effects(2, peer_id), weapon.data, weapon.data.pellets * 2)
	assert_true(_sessions[1].remote_shots._points.is_empty())


func test_coachman_primary_packet_still_relays_one_barrel() -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var shooter: Player = _sessions[1].players.find_player(peer_id)
	var weapon: Weapon = shooter.weapons.replace_current(Content.weapon(&"coachman_2b"))
	weapon.fire()
	await wait_until(func() -> bool: return _effects(2, peer_id).has_node("Tracers"), 3.0, "one barrel relayed")
	_assert_shot(_effects(2, peer_id), weapon.data)
	assert_eq(weapon.instance.ammo_in_mag, 1)


func test_wrong_pellet_counts_are_dropped_for_double_and_normal_guns() -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var shots: RemoteShots = _sessions[1].remote_shots
	var invalid: Dictionary[StringName, Array] = {
		&"coachman_2b": [0, 1, 9, 11, 19, 21, 30],
		&"grubber_sawnoff": [0, 1, 7, 9, 15, 17, 24],
		&"rifle_ar": [0, 2, 30, 60],
		&"brenner_trench": [0, 7, 9, 16],
	}
	for weapon_id: StringName in invalid:
		for count: int in invalid[weapon_id]:
			var points: PackedVector3Array = PackedVector3Array()
			points.resize(count)
			points.fill(Vector3.FORWARD * 50.0)
			shots.shot.rpc_id(1, weapon_id, Vector3.ZERO, points)
	await wait_physics_frames(8)
	assert_false(_effects(0, peer_id).has_node("Tracers"), "host rejected all malformed pellet counts")
	assert_false(_effects(2, peer_id).has_node("Tracers"), "observer received no rejected packets")


func _assert_shot(effects: RemoteShotEffects, data: WeaponData, pellet_count: int = -1) -> void:
	var tracers: Array[Node] = effects.find_children("Tracers*", "MeshInstance3D", false, false)
	assert_eq(tracers.size(), 1, "one packet renders one shot, including a shotgun")
	if tracers.size() != 1:
		return
	var mesh: Mesh = (tracers[0] as MeshInstance3D).mesh
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var expected: int = data.pellets if pellet_count < 0 else pellet_count
	assert_eq(vertices.size(), expected * 2, "every missed pellet has a full-range tracer")
	for index: int in range(0, vertices.size(), 2):
		assert_gt(vertices[index].distance_to(vertices[index + 1]), data.max_range - 2.0)
	assert_true(effects._flash.visible)
	assert_true(effects._light.visible)
	assert_eq(effects._audio.stream, data.fire_sound)
	assert_eq(effects._audio.bus, &"Weapons")

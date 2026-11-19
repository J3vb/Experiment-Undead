## Real ENet peers relay one cosmetic shot, with no owner echo or gameplay changes.
extends GutTest

const _NO_HITS: PackedVector3Array = []
const _NO_KINDS: PackedByteArray = []

var _port: int
var _roots: Array[Node] = []
var _sessions: Array[GameSession] = []


func _make_side(side_name: String) -> Node:
	var session: GameSession = CoopSide.make(self, side_name, [&"remote_shots"])
	_sessions.append(session)
	session.players.player_added.connect(
		func(player: Player) -> void:
			player.spawn(session, [Content.weapon(&"brenner_trench")])
			player.set_physics_process(false)
			session.remote_shots.watch_player(player)
	)
	_roots.append(session.get_parent())
	return session.get_parent()


func before_each() -> void:
	_port = TwoPeers.next_port()
	var server: Node = _make_side("Server")
	var client: Node = _make_side("Client")
	var observer: Node = _make_side("Observer")
	assert_eq(TwoPeers.host(server, _port, 3), OK)
	for root: Node in [client, observer]:
		assert_eq(TwoPeers.join(root, _port), OK)
	for index: int in [1, 2, 0]:
		CoopSide.start_players(_sessions[index])
	await wait_until(
		func() -> bool:
			return (
				CoopSide.players(_sessions[0]).size() == 3
				and CoopSide.players(_sessions[1]).size() == 3
				and CoopSide.players(_sessions[2]).size() == 3
			),
		5.0,
		"three peers see three players"
	)


func after_each() -> void:
	_sessions.reverse()
	for session: GameSession in _sessions:
		CoopSide.close(session)
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
	var points_before: int = server_copy.wallet.points
	weapon.fire()
	await wait_until(
		func() -> bool: return _drawn(host_effects) and _drawn(other_effects), 3.0, "client shot relayed through server"
	)
	assert_false(shooter.has_node("ShotEffects"), "owner only plays its original local effects")
	_assert_shot(host_effects, weapon.data)
	_assert_shot(other_effects, weapon.data)
	assert_eq(server_copy.health.current, health_before, "cosmetics do no damage")
	assert_eq(server_copy.wallet.points, points_before, "cosmetics award no points")
	assert_eq(server_copy.weapons.current.instance.ammo_in_mag, weapon.data.magazine_size)
	assert_eq(weapon.instance.ammo_in_mag, weapon.data.magazine_size - 1, "one shell for all pellets")
	assert_true(_sessions[1].remote_shots._points.is_empty(), "shot flushes its endpoints")
	assert_true(_sessions[1].remote_shots._hits.is_empty(), "pellets that hit nothing relay no impacts")


func test_host_shot_reaches_both_clients_without_echo() -> void:
	var host: Player = _sessions[0].players.find_player(1)
	var client_effects: RemoteShotEffects = _effects(1, 1)
	var other_effects: RemoteShotEffects = _effects(2, 1)
	host.weapons.current.fire()
	await wait_until(
		func() -> bool: return _drawn(client_effects) and _drawn(other_effects), 3.0, "host shot reaches clients"
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
	await wait_until(func() -> bool: return _drawn(effects), 3.0, "replacement gun shot relayed")
	_assert_shot(effects, weapon.data)


func test_bad_cosmetic_packets_are_dropped() -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var shots: RemoteShots = _sessions[1].remote_shots
	shots.shot.rpc_id(1, &"missing", Vector3.ZERO, PackedVector3Array([Vector3.ONE]), _NO_HITS, _NO_KINDS)
	shots.shot.rpc_id(1, &"brenner_trench", Vector3.ZERO, PackedVector3Array([Vector3.ONE]), _NO_HITS, _NO_KINDS)
	await wait_physics_frames(8)
	assert_false(_drawn(_effects(0, peer_id)))
	assert_false(_drawn(_effects(2, peer_id)))


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
		func() -> bool: return _drawn(_effects(0, peer_id)) and _drawn(_effects(2, peer_id)),
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
	await wait_until(func() -> bool: return _drawn(_effects(2, peer_id)), 3.0, "one barrel relayed")
	_assert_shot(_effects(2, peer_id), weapon.data)
	assert_eq(weapon.instance.ammo_in_mag, 1)


func test_grubber_plus_one_pellet_relays_nine_primary_and_eighteen_alt_endpoints() -> void:
	await _check_runtime_pellets(&"grubber_sawnoff", 1, false)
	await _wait_for_previous_tracers()
	await _check_runtime_pellets(&"grubber_sawnoff", 1, true)


func test_coachman_plus_one_pellet_relays_eleven_primary_and_twenty_two_alt_endpoints() -> void:
	await _check_runtime_pellets(&"coachman_2b", 1, false)
	await _wait_for_previous_tracers()
	await _check_runtime_pellets(&"coachman_2b", 1, true)


func test_grubber_max_pellet_bonus_primary_relays_ten_endpoints() -> void:
	await _check_runtime_pellets(&"grubber_sawnoff", 2, false)


func test_grubber_max_pellet_bonus_alt_relays_twenty_endpoints() -> void:
	await _check_runtime_pellets(&"grubber_sawnoff", 2, true)


func test_coachman_max_pellet_bonus_primary_relays_twelve_endpoints() -> void:
	await _check_runtime_pellets(&"coachman_2b", 2, false)


func test_coachman_max_pellet_bonus_alt_relays_twenty_four_endpoints() -> void:
	await _check_runtime_pellets(&"coachman_2b", 2, true)


func _wait_for_previous_tracers() -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var expired: bool = await wait_until(
		func() -> bool: return not _drawn(_effects(0, peer_id)) and not _drawn(_effects(2, peer_id)),
		3.0,
		"the previous host and observer tracers expire"
	)
	assert_true(expired, "the next payload is checked separately from the previous shot")


func _check_runtime_pellets(weapon_id: StringName, bonus: int, alternate: bool) -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var shooter: Player = _sessions[1].players.find_player(peer_id)
	var base: WeaponData = Content.weapon(weapon_id)
	var tier: int = 1 if bonus == 1 else 5
	var roll: float = 0.0 if bonus == 1 else 1.0
	var item: ItemInstance = ItemInstance.new({"uid": "remote_pellets", "aff": [["pellets", tier, roll]]})
	var snapshot: WeaponData = item.weapon_data(base)
	assert_eq(snapshot.pellets, base.pellets + bonus, "the equipped item supplies the runtime pellet count")
	var weapon: Weapon = shooter.weapons.replace_current(snapshot)
	watch_signals(weapon)
	if alternate:
		shooter.last_frame.buttons = InputFrame.ALT_FIRE
		weapon.tick(1.0 / 60.0)
	else:
		weapon.fire()
	await wait_until(
		func() -> bool: return _drawn(_effects(0, peer_id)) and _drawn(_effects(2, peer_id)),
		3.0,
		"the equipped item's pellets reach host and observer"
	)
	assert_eq(weapon.instance.ammo_in_mag, 0 if alternate else 1)
	assert_signal_emit_count(weapon, "fired", 1, "all runtime pellets belong to one shot")
	assert_false(shooter.has_node("ShotEffects"), "the owner receives no effect echo")
	var pellets: int = snapshot.pellets * (2 if alternate else 1)
	_assert_shot(_effects(0, peer_id), snapshot, pellets)
	_assert_shot(_effects(2, peer_id), snapshot, pellets)
	assert_eq(base.pellets, 10 if weapon_id == &"coachman_2b" else 8, "shared content remains unchanged")


func test_wrong_pellet_counts_are_dropped_for_double_and_normal_guns() -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var shots: RemoteShots = _sessions[1].remote_shots
	var invalid: Dictionary[StringName, Array] = {
		&"coachman_2b": [0, 1, 9, 13, 19, 21, 23, 25, 30],
		&"grubber_sawnoff": [0, 1, 7, 11, 15, 17, 19, 21, 24],
		&"rifle_ar": [0, 2, 30, 60],
		&"brenner_trench": [0, 7, 11, 16],
	}
	for weapon_id: StringName in invalid:
		for count: int in invalid[weapon_id]:
			var points: PackedVector3Array = PackedVector3Array()
			points.resize(count)
			points.fill(Vector3.FORWARD * 50.0)
			shots.shot.rpc_id(1, weapon_id, Vector3.ZERO, points, _NO_HITS, _NO_KINDS)
	await wait_physics_frames(8)
	assert_false(_drawn(_effects(0, peer_id)), "host rejected all malformed pellet counts")
	assert_false(_drawn(_effects(2, peer_id)), "observer received no rejected packets")


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


func test_downed_client_sidearm_shot_reaches_host_and_other_client() -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var shooter: Player = _sessions[1].players.find_player(peer_id)
	var server_copy: Player = _sessions[0].players.find_player(peer_id)
	server_copy.take_damage(DamageInfo.create(1000.0, null))
	await wait_until(func() -> bool: return shooter.is_downed, 3.0, "owner sees downed state")
	assert_eq(shooter.weapons.current.data.id, &"pistol_service")
	var host_effects: RemoteShotEffects = _effects(0, peer_id)
	var other_effects: RemoteShotEffects = _effects(2, peer_id)
	shooter.weapons.current.fire()
	await wait_until(
		func() -> bool: return _drawn(host_effects) and _drawn(other_effects), 3.0, "downed sidearm cosmetics relayed"
	)
	_assert_shot(host_effects, shooter.weapons.current.data)
	_assert_shot(other_effects, shooter.weapons.current.data)
	assert_false(shooter.has_node("ShotEffects"), "owner receives no duplicate cosmetics")


func test_downed_rifle_and_dead_sidearm_cosmetic_requests_are_refused() -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var shooter: Player = _sessions[1].players.find_player(peer_id)
	var server_copy: Player = _sessions[0].players.find_player(peer_id)
	var shots: RemoteShots = _sessions[1].remote_shots
	var points: PackedVector3Array = PackedVector3Array([Vector3.FORWARD * 100.0])
	server_copy.take_damage(DamageInfo.create(1000.0, null))
	await wait_until(func() -> bool: return shooter.is_downed, 3.0, "owner sees downed state")
	shots.shot.rpc_id(1, &"rifle_ar", Vector3.ZERO, points, _NO_HITS, _NO_KINDS)
	await wait_physics_frames(8)
	assert_null(_effects(0, peer_id)._audio.stream, "downed rifle shot is not relayed to host")
	assert_null(_effects(2, peer_id)._audio.stream, "downed rifle shot is not relayed to observer")
	server_copy.state_sync._physics_process(30.0)
	assert_true(server_copy.is_dead)
	shots.shot.rpc_id(1, &"pistol_service", Vector3.ZERO, points, _NO_HITS, _NO_KINDS)
	await wait_physics_frames(8)
	assert_null(_effects(0, peer_id)._audio.stream, "dead sidearm shot is not relayed to host")
	assert_null(_effects(2, peer_id)._audio.stream, "dead sidearm shot is not relayed to observer")


func test_finished_match_refuses_cosmetic_requests() -> void:
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	_sessions[0].is_over = true
	_sessions[1].remote_shots.shot.rpc_id(
		1, &"rifle_ar", Vector3.ZERO, PackedVector3Array([Vector3.FORWARD * 100.0]), _NO_HITS, _NO_KINDS
	)
	await wait_physics_frames(8)
	assert_null(_effects(0, peer_id)._audio.stream)
	assert_null(_effects(2, peer_id)._audio.stream)


func _drawn(effects: RemoteShotEffects) -> bool:
	var tracers: Node3D = effects.get_node_or_null("Tracers") as Node3D
	return tracers != null and tracers.visible

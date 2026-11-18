## Teammates' shots carry their real hits: each hit shows an impact of the
## kind the shooter saw, and the server drops malformed hit lists.
extends GutTest

const RIFLE: String = "res://content/weapons/rifle_ar.tres"

var _effects: RemoteShotEffects
var _roots: Array[Node] = []
var _sessions: Array[GameSession] = []


func before_each() -> void:
	Impact._ring.clear()
	Impact._next = 0
	_effects = RemoteShotEffects.new()
	add_child_autofree(_effects)


func after_each() -> void:
	_sessions.reverse()
	for session: GameSession in _sessions:
		CoopSide.close(session)
	_roots.clear()
	_sessions.clear()


## A host, a shooting client and an observing client, each with RemoteShots watching its own player.
func _three_peers() -> void:
	var port: int = TwoPeers.next_port()
	for side_name: String in ["Server", "Client", "Observer"]:
		var session: GameSession = CoopSide.make(self, side_name, [&"remote_shots"])
		session.players.player_added.connect(_arm.bind(session, session.remote_shots))
		_roots.append(session.get_parent())
		_sessions.append(session)
	assert_eq(TwoPeers.host(_roots[0], port, 3), OK)
	assert_eq(TwoPeers.join(_roots[1], port), OK)
	assert_eq(TwoPeers.join(_roots[2], port), OK)
	for index: int in [1, 2, 0]:
		CoopSide.start_players(_sessions[index])
	await wait_until(_all_see_three, 5.0, "three peers see three players")


func _arm(player: Player, session: GameSession, shots: RemoteShots) -> void:
	player.spawn(session, [Content.weapon(&"brenner_trench")])
	player.set_physics_process(false)
	shots.watch_player(player)


func _all_see_three() -> bool:
	for session: GameSession in _sessions:
		if CoopSide.players(session).size() != 3:
			return false
	return true


func _surface_impacts() -> int:
	var count: int = 0
	for impact: Impact in Impact._ring:
		if is_instance_valid(impact) and impact.visible and not impact._flesh.visible:
			count += 1
	return count


func test_client_shot_into_a_wall_shows_its_impacts_on_host_and_observer() -> void:
	await _three_peers()
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(40, 40, 1)
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.position = Vector3(0, 0, -4)
	await wait_physics_frames(2)
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var weapon: Weapon = _sessions[1].players.find_player(peer_id).weapons.current
	weapon.fire()
	var pellets: int = weapon.data.pellets
	await wait_until(func() -> bool: return _surface_impacts() >= pellets * 2, 3.0, "host and observer show the hits")
	assert_eq(
		_surface_impacts(), pellets * 2, "the host's and the observer's dust (the shooter's own needs a current scene)"
	)
	assert_true(_sessions[1].remote_shots._hits.is_empty(), "hits flushed with the shot")


func test_server_drops_a_shot_whose_hits_and_kinds_disagree() -> void:
	await _three_peers()
	var peer_id: int = _roots[1].multiplayer.get_unique_id()
	var points: PackedVector3Array = []
	points.resize(8)
	points.fill(Vector3(0, 0, -5))
	var hits: PackedVector3Array = [Vector3(0, 0, -5), Vector3(0, 0, -5)]
	_sessions[1].remote_shots.shot.rpc_id(1, &"brenner_trench", Vector3.ZERO, points, hits, PackedByteArray([1]))
	await wait_physics_frames(8)
	var observer: RemoteShotEffects = (
		_sessions[2].players.find_player(peer_id).get_node("ShotEffects") as RemoteShotEffects
	)
	assert_null(observer.get_node_or_null("Tracers"), "the bad shot is not relayed")
	assert_eq(Impact._ring.size(), 0)


func test_each_hit_shows_an_impact_of_its_kind() -> void:
	var hits: PackedVector3Array = [Vector3(1, 1, -3), Vector3(1, 1.6, -4), Vector3(0, 0.5, -6)]
	var kinds: PackedByteArray = [Impact.Kind.FLESH, Impact.Kind.HEAD, Impact.Kind.SURFACE]
	_effects.show_hits(Vector3.ZERO, hits, kinds)
	assert_eq(Impact._ring.size(), 3)
	assert_true(Impact._ring[0]._flesh.visible, "body hit bleeds")
	assert_true(Impact._ring[1]._flesh.visible, "head hit bleeds")
	assert_false(Impact._ring[2]._flesh.visible, "wall hit makes dust")
	assert_almost_eq(Impact._ring[1].global_position.distance_to(hits[1]), 0.0, 0.02)
	assert_gt(Impact._ring[0].global_position.z, hits[0].z, "impact faces back toward the shooter")


func test_a_shot_that_hit_nothing_shows_no_impacts() -> void:
	_effects.play(load(RIFLE) as WeaponData, Vector3.ZERO, PackedVector3Array([Vector3.FORWARD * 10.0]))
	_effects.show_hits(Vector3.ZERO, PackedVector3Array(), PackedByteArray())
	assert_eq(Impact._ring.size(), 0)


func test_bad_hit_lists_are_dropped() -> void:
	var shots: RemoteShots = RemoteShots.new()
	var one: PackedVector3Array = [Vector3.ONE]
	assert_true(shots._valid_hits(8, one, PackedByteArray([Impact.Kind.HEAD])))
	assert_true(shots._valid_hits(1, PackedVector3Array(), PackedByteArray()), "a miss has no hits")
	assert_false(shots._valid_hits(8, one, PackedByteArray()), "one kind per hit")
	assert_false(shots._valid_hits(8, one, PackedByteArray([3])), "unknown impact kind")
	assert_false(shots._valid_hits(8, PackedVector3Array([Vector3(INF, 0, 0)]), PackedByteArray([1])), "not finite")
	var many: PackedVector3Array = []
	many.resize(8 * RemoteShots.MAX_HITS_PER_PELLET + 1)
	var many_kinds: PackedByteArray = []
	many_kinds.resize(many.size())
	assert_false(shots._valid_hits(8, many, many_kinds), "more hits than pierce allows")
	shots.free()


func test_pierced_and_killing_hits_keep_the_kind_the_shooter_saw() -> void:
	var shots: RemoteShots = RemoteShots.new()
	shots._hits.append(Vector3.ONE)
	shots._kinds.append(Impact.Kind.FLESH)
	var zone: HitZone = HitZone.new()
	zone.zone = DamageInfo.Zone.HEAD
	zone.set_enabled(false)
	shots._kinds.append(Impact.kind_for(zone))
	shots._hits.append(Vector3.ONE * 2.0)
	assert_eq(shots._kinds[1], Impact.Kind.HEAD, "a killing head hit (zones already off) still relays as HEAD")
	assert_true(shots._valid_hits(1, shots._hits, shots._kinds), "two pierced hits from one pellet are allowed")
	zone.free()
	shots.free()

## Co-op frag throws (docs/plans/frag-grenades.md, step 2): two ENet peers prove the
## server throws the real grenade, the client only shows copies, and bad throws are refused.
extends GutTest

const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")

var _port: int
var _server: GameSession
var _client: GameSession
var _server_grenades: GrenadeClaims
var _client_grenades: GrenadeClaims
var _peer_id: int


class RecordingClaims:
	extends HitClaims

	var reasons: Array[StringName] = []

	func reject(sender: int, reason: StringName) -> void:
		reasons.append(reason)
		super(sender, reason)


func before_each() -> void:
	_port = TwoPeers.next_port()
	_server = _make_side("GrenadeServer")
	_client = _make_side("GrenadeClient")
	_server_grenades = _server.get_node("GrenadeClaims") as GrenadeClaims
	_client_grenades = _client.get_node("GrenadeClaims") as GrenadeClaims
	assert_eq(TwoPeers.host(_server, _port, 2), OK)
	assert_eq(TwoPeers.join(_client, _port), OK)
	await wait_until(
		func() -> bool: return _client.multiplayer.get_unique_id() > 1 and _server.multiplayer.get_peers().size() == 1,
		5.0,
		"grenade peers connected"
	)
	_peer_id = _client.multiplayer.get_unique_id()
	for session: GameSession in [_server, _client]:
		_add_player(session, 1)
		_add_player(session, _peer_id)


func after_each() -> void:
	for session: GameSession in [_client, _server]:
		CoopSide.close(session)


func _make_side(side_name: String) -> GameSession:
	var session: GameSession = CoopSide.make(self, side_name, [&"grenade_claims"], null, RecordingClaims.new())
	CoopSide.add_spawn_point(session)
	session.hit_claims.set_physics_process(false)
	return session


func _add_player(session: GameSession, peer_id: int) -> void:
	var player: Player = CoopSide.add_player(session, peer_id)
	session.economy._on_player_spawned(player)
	player.wallet.set_points(0)
	player.local_input.enabled = false


func _grenades(session: GameSession) -> Array[Grenade]:
	var out: Array[Grenade] = []
	for child: Node in session.get_children():
		if child is Grenade and not child.is_queued_for_deletion():
			out.append(child as Grenade)
	return out


func _reasons() -> Array[StringName]:
	return (_server.hit_claims as RecordingClaims).reasons


func _client_throw(origin_offset: Vector3 = Vector3.ZERO, fuse: float = 2.0) -> void:
	var player: Player = _client.players.find_player(_peer_id)
	var origin: Vector3 = player.camera.global_position + origin_offset
	_client_grenades.request_throw(player, origin, Vector3(0, 2, -10), fuse)


func test_client_throw_makes_the_real_grenade_on_the_server_only() -> void:
	_client_throw()
	await wait_until(func() -> bool: return _grenades(_server).size() == 1, 3.0, "server threw the frag")
	var real: Grenade = _grenades(_server)[0]
	assert_true(real.gameplay)
	assert_same(real.thrower, _server.players.find_player(_peer_id))
	var copies: Array[Grenade] = _grenades(_client)
	assert_eq(copies.size(), 1, "the owner sees its own throw at once")
	assert_false(copies[0].gameplay, "the client copy never does damage")


func test_server_owns_the_count_and_the_client_follows() -> void:
	_client_throw()
	await wait_until(func() -> bool: return _grenades(_server).size() == 1, 3.0, "server threw the frag")
	assert_eq(_server.players.find_player(_peer_id).grenades.count, 1)
	await wait_until(
		func() -> bool: return _client.players.find_player(_peer_id).grenades.count == 1, 3.0, "count synced back"
	)


func test_no_grenades_left_is_refused() -> void:
	_server.players.find_player(_peer_id).grenades.count = 0
	_client_throw()
	await wait_until(func() -> bool: return _reasons().has(&"grenade_none_left"), 3.0, "refused")
	assert_eq(_grenades(_server).size(), 0)


func test_throw_far_from_the_thrower_is_refused() -> void:
	_client_throw(Vector3(50, 0, 0))
	await wait_until(func() -> bool: return _reasons().has(&"grenade_bad_throw"), 3.0, "refused")
	assert_eq(_grenades(_server).size(), 0)


func test_a_longer_fuse_than_the_frag_has_is_refused() -> void:
	_client_throw(Vector3.ZERO, 30.0)
	await wait_until(func() -> bool: return _reasons().has(&"grenade_bad_throw"), 3.0, "refused")
	assert_eq(_grenades(_server).size(), 0)


func test_two_throws_at_once_are_too_fast() -> void:
	_client_throw()
	_client_throw()
	await wait_until(func() -> bool: return _reasons().has(&"grenade_too_fast"), 3.0, "second throw refused")
	assert_eq(_grenades(_server).size(), 1)
	assert_eq(_server.players.find_player(_peer_id).grenades.count, 1, "only one taken")


func test_client_frag_kills_on_the_server_and_both_see_the_blast_there() -> void:
	var zombie: Zombie = _server.spawner.spawn(WALKER, 1, RULES)
	zombie.set_physics_process(false)
	zombie.health.reset(50.0)
	var player: Player = _client.players.find_player(_peer_id)
	zombie.global_position = player.global_position + Vector3(0, 0, -2)
	watch_signals(_client_grenades)
	watch_signals(_server_grenades)
	_client_grenades.request_throw(player, player.camera.global_position, Vector3.ZERO, 0.1)
	await wait_until(func() -> bool: return zombie.health.is_dead, 3.0, "the frag killed on the server")
	await wait_until(
		func() -> bool: return get_signal_emit_count(_client_grenades, "blast_shown") == 1, 3.0, "client saw the blast"
	)
	var on_server: Array = get_signal_parameters(_server_grenades, "blast_shown")
	var on_client: Array = get_signal_parameters(_client_grenades, "blast_shown")
	assert_eq(on_client[0], _peer_id)
	assert_eq(on_client[1], on_server[1], "the client blast is where the server's went off")


func test_host_throw_shows_a_copy_on_the_client() -> void:
	var host: Player = _server.players.find_player(1)
	_server_grenades.request_throw(host, host.camera.global_position, Vector3(0, 2, -10), 2.0)
	assert_eq(_grenades(_server).size(), 1)
	await wait_until(func() -> bool: return _grenades(_client).size() == 1, 3.0, "client saw the host's throw")
	assert_false(_grenades(_client)[0].gameplay)

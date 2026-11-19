## Shared two-peer fixture for gravity well claim tests: a server and a client,
## each with its own GameSession, HitClaims, WellClaims and both players.
extends GutTest

const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")
const SIPHON: StringName = &"siphon"

var _port: int
var _server: GameSession
var _client: GameSession
var _server_claims: HitClaims
var _client_claims: HitClaims
var _server_wells: WellClaims
var _client_wells: WellClaims
var _peer_id: int


class RecordingClaims:
	extends HitClaims

	var reasons: Array[StringName] = []

	func reject(sender: int, reason: StringName) -> void:
		reasons.append(reason)
		super(sender, reason)


func before_each() -> void:
	_port = TwoPeers.next_port()
	_server = _make_side("WellServer")
	_client = _make_side("WellClient")
	_server_claims = _server.get_node("HitClaims") as HitClaims
	_client_claims = _client.get_node("HitClaims") as HitClaims
	_server_wells = _server.get_node("WellClaims") as WellClaims
	_client_wells = _client.get_node("WellClaims") as WellClaims
	assert_eq(TwoPeers.host(_server, _port, 2), OK)
	assert_eq(TwoPeers.join(_client, _port), OK)
	await wait_until(
		func() -> bool: return _client.multiplayer.get_unique_id() > 1 and _server.multiplayer.get_peers().size() == 1,
		5.0,
		"well claim peers connected"
	)
	_peer_id = _client.multiplayer.get_unique_id()
	for session: GameSession in [_server, _client]:
		_add_player(session, 1)
		_add_player(session, _peer_id)


func after_each() -> void:
	for session: GameSession in [_client, _server]:
		CoopSide.close(session)


func _make_side(side_name: String) -> GameSession:
	var session: GameSession = CoopSide.make(self, side_name, [&"well_claims"], null, RecordingClaims.new())
	CoopSide.add_spawn_point(session)
	session.hit_claims.set_physics_process(false)
	(session.get_node("WellClaims") as WellClaims).set_physics_process(false)
	return session


func _add_player(session: GameSession, peer_id: int) -> void:
	var player: Player = CoopSide.add_player(session, peer_id)
	session.economy._on_player_spawned(player)
	player.wallet.set_points(0)
	player.local_input.enabled = false


func _wells(session: GameSession) -> Array[GravityWell]:
	var wells: Array[GravityWell] = []
	for child: Node in session.get_children():
		var well: GravityWell = child as GravityWell
		if well and well.is_in_group(&"gravity_wells") and not well.collapsed:
			wells.append(well)
	return wells


func _rejections() -> int:
	return Log.event_counts.get("net.hit_claim_rejected", 0)


func _spawn_pair() -> Array[Zombie]:
	var zombie: Zombie = _server.spawner.spawn(WALKER, 1, RULES)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(1.0, 0.0, 0.0)
	var path: NodePath = NodePath(String(zombie.name))
	await wait_until(func() -> bool: return _client.spawner.has_node(path), 3.0, "client zombie appeared")
	return [zombie, _client.spawner.get_node(path) as Zombie]

## Shared two-peer fixture for gravity well claim tests: a server and a client,
## each with its own GameSession, HitClaims and both players.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const HUD: PackedScene = preload("res://systems/ui/hud.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")
const ECONOMY: String = "res://content/economy/default_economy.tres"
const SIPHON: StringName = &"siphon"

var _server: GameSession
var _client: GameSession
var _server_claims: HitClaims
var _client_claims: HitClaims
var _peer_id: int


class FixtureSession:
	extends GameSession

	func _ready() -> void:
		pass

	func _exit_tree() -> void:
		pass


class RecordingClaims:
	extends HitClaims

	var reasons: Array[StringName] = []

	func _reject(sender: int, reason: StringName) -> void:
		reasons.append(reason)
		super(sender, reason)


## Override in a test file to use another port.
func port() -> int:
	return 24665


func before_each() -> void:
	_server = _make_side("WellServer")
	_client = _make_side("WellClient")
	_server_claims = _server.get_node("HitClaims") as HitClaims
	_client_claims = _client.get_node("HitClaims") as HitClaims
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(port(), 2), OK)
	_server.multiplayer.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", port()), OK)
	_client.multiplayer.multiplayer_peer = client_peer
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
		var root: Node = session.get_parent()
		var path: NodePath = root.get_path()
		session.multiplayer.multiplayer_peer.close()
		session.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		root.free()
		get_tree().set_multiplayer(null, path)


func _make_side(side_name: String) -> GameSession:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var session: GameSession = FixtureSession.new()
	session.name = "GameSession"
	session.rng.seed = 7
	var economy: Economy = Economy.new()
	economy.rules = load(ECONOMY)
	var children: Dictionary[StringName, Node] = {
		&"WaveDirector": WaveDirector.new(),
		&"Economy": economy,
		&"Progression": ProgressionService.new(),
		&"PowerUpDrops": PowerUpDrops.new(),
		&"Hud": HUD.instantiate(),
		&"Actors": Node3D.new(),
	}
	for node_name: StringName in children:
		children[node_name].name = node_name
		session.add_child(children[node_name])
	session.players = PlayerSpawner.new()
	session.players.name = "PlayerSpawner"
	session.players._parent = children[&"Actors"] as Node3D
	session.add_child(session.players)
	session.spawner = Spawner.new()
	session.spawner.name = "Enemies"
	session.spawner.session = session
	session.spawner.spawn_group = &"test_well_claim_spawns"
	session.add_child(session.spawner)
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_well_claim_spawns")
	session.add_child(marker)
	var claims: HitClaims = RecordingClaims.new()
	claims.name = "HitClaims"
	claims.session = session
	session.add_child(claims)
	root.add_child(session)
	session.set_physics_process(false)
	session.set_process_unhandled_input(false)
	claims.set_physics_process(false)
	return session


func _add_player(session: GameSession, peer_id: int) -> void:
	var player: Player = PLAYER.instantiate() as Player
	player.name = str(peer_id)
	player.net_id = peer_id
	player.session = session
	player.set_multiplayer_authority(peer_id)
	session.get_node("Actors").add_child(player)
	session.economy._on_player_spawned(player)
	player.wallet.set_points(0)
	player.local_input.enabled = false
	player.set_physics_process(false)


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

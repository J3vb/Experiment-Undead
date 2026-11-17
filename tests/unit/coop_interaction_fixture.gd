## Shared two-peer fixture for co-op interaction tests: a server with no local
## player (like a dedicated server), a client, and an optional late joiner.
## Each side has its own GameSession, Economy, Level and InteractionSync.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const HUD: PackedScene = preload("res://systems/ui/hud.tscn")
const DOOR: PackedScene = preload("res://systems/interactables/door.tscn")
const POWER_SWITCH: PackedScene = preload("res://systems/interactables/power_switch.tscn")
const WALL_BUY: PackedScene = preload("res://systems/interactables/wall_buy.tscn")
const ECONOMY: String = "res://content/economy/default_economy.tres"

var server: GameSession
var client: GameSession
var late: GameSession
var client_id: int
var _sessions: Array[GameSession] = []


class FixtureSession:
	extends GameSession

	func _ready() -> void:
		pass

	func _exit_tree() -> void:
		pass


## Override in a test file to use another port.
func port() -> int:
	return 24701


func before_each() -> void:
	_sessions.clear()
	late = null
	server = make_side("InteractServer")
	client = make_side("InteractClient")
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(port(), 3), OK)
	server.multiplayer.multiplayer_peer = server_peer
	await join(client)
	client_id = client.multiplayer.get_unique_id()
	add_player(server, client_id)
	add_player(client, client_id)
	await wait_physics_frames(2)


func after_each() -> void:
	for session: GameSession in _sessions:
		var root: Node = session.get_parent()
		var path: NodePath = root.get_path()
		session.multiplayer.multiplayer_peer.close()
		session.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		root.free()
		get_tree().set_multiplayer(null, path)


func join(session: GameSession) -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", port()), OK)
	session.multiplayer.multiplayer_peer = peer
	var peers: int = server.multiplayer.get_peers().size() + 1
	await wait_until(
		func() -> bool:
			return session.multiplayer.get_unique_id() > 1 and server.multiplayer.get_peers().size() == peers,
		5.0,
		"peer connected"
	)


func make_side(side_name: String) -> GameSession:
	var root: Node = Node.new()
	root.name = side_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var session: GameSession = FixtureSession.new()
	session.name = "GameSession"
	var economy: Economy = Economy.new()
	economy.rules = load(ECONOMY)
	var children: Dictionary[StringName, Node] = {
		&"WaveDirector": WaveDirector.new(),
		&"Economy": economy,
		&"Progression": ProgressionService.new(),
		&"PowerUpDrops": PowerUpDrops.new(),
		&"Hud": HUD.instantiate(),
	}
	for node_name: StringName in children:
		children[node_name].name = node_name
		session.add_child(children[node_name])
	session.level = build_level()
	session.add_child(session.level)
	session.players = PlayerSpawner.new()
	session.players.name = "PlayerSpawner"
	session.players._parent = session.level
	session.add_child(session.players)
	session.interactions = InteractionSync.new()
	session.interactions.session = session
	session.add_child(session.interactions)
	root.add_child(session)
	session.set_physics_process(false)
	session.set_process_unhandled_input(false)
	_sessions.append(session)
	return session


## The same map on every peer. Players stand at the origin.
func build_level() -> Level:
	var level: Level = Level.new()
	level.name = "Level"
	_add_door(level, "EastDoor", &"east", 1000, Vector3(1.5, 1, 0))
	_add_door(level, "WestDoor", &"west", 1000, Vector3(-1.5, 1, 0))
	var power_door: Door = _add_door(level, "PowerDoor", &"labs", 0, Vector3(0, 1, 2))
	power_door.needs_power = true
	var switch: PowerSwitch = POWER_SWITCH.instantiate() as PowerSwitch
	switch.name = "PowerSwitch"
	switch.position = Vector3(0, 1, -1.5)
	level.add_child(switch)
	var wall: WallBuy = WALL_BUY.instantiate() as WallBuy
	wall.name = "WallBuy"
	wall.weapon = Content.weapon(&"kestrel_smg")
	wall.position = Vector3(1.5, 1, 1.5)
	level.add_child(wall)
	var point: ZombieSpawnPoint = ZombieSpawnPoint.new()
	point.name = "EastSpawn"
	point.area = &"east"
	level.add_child(point)
	point.owner = level
	return level


func _add_door(level: Level, door_name: String, area: StringName, cost: int, at: Vector3) -> Door:
	var door: Door = DOOR.instantiate() as Door
	door.name = door_name
	door.opens_area = area
	door.cost = cost
	door.position = at
	var blocker: StaticBody3D = StaticBody3D.new()
	blocker.name = "Blocker"
	door.add_child(blocker)
	level.add_child(door)
	return door


func add_player(session: GameSession, peer_id: int) -> Player:
	var player: Player = PLAYER.instantiate() as Player
	player.name = str(peer_id)
	player.net_id = peer_id
	player.session = session
	player.set_multiplayer_authority(peer_id)
	session.level.add_child(player)
	player.set_physics_process(false)
	return player


func on_server(peer_id: int = client_id) -> Player:
	return server.players.find_player(peer_id)


func on_client(session: GameSession = client) -> Player:
	return session.players.find_player(session.multiplayer.get_unique_id())


func target(session: GameSession, node_name: String) -> Interactable:
	return session.level.get_node_or_null(node_name) as Interactable


func gone(session: GameSession, node_name: String) -> bool:
	var node: Node = session.level.get_node_or_null(node_name)
	return node == null or node.is_queued_for_deletion()


## Sends a client request for the named interactable and waits for the server to read it.
func press(node_name: String, session: GameSession = client) -> void:
	session.interactions.request(on_client(session), target(session, node_name))
	await wait_physics_frames(6)


func denied_on(session: GameSession, node_name: String) -> bool:
	var node: Interactable = target(session, node_name)
	return node != null and (node.get_node("DeniedSound") as AudioStreamPlayer3D).playing

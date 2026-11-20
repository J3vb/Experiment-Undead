## Test helper: one co-op side (a TwoPeers subtree) holding a GameSession wired the way
## GameSession._ready(), _setup_level() and _setup_shooting() wire it, without a level scene,
## handshake or network start. A test names the shooting systems it needs as parts.
class_name CoopSide
extends RefCounted

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const HUD: PackedScene = preload("res://systems/ui/hud.tscn")
const ECONOMY: EconomyRules = preload("res://content/economy/default_economy.tres")
const WAVES: WaveRules = preload("res://content/waves/default_waves.tres")
const SEED: int = 7


## A GameSession that leaves its setup to CoopSide.
class Session:
	extends GameSession

	func _ready() -> void:
		pass

	func _exit_tree() -> void:
		pass


## Adds a side named side_name under parent holding a GameSession with the scene's children
## (WaveDirector, Economy, Progression, PowerUpDrops, Hud), MatchEnd, a Level with the "Enemies" Spawner,
## a PlayerSpawner, and the parts asked for: hit_claims, well_claims, loot, remote_shots,
## interactions, deploy_vote. level replaces the empty Level; claims replaces the plain HitClaims.
static func make(
	parent: Node, side_name: String, parts: Array[StringName] = [], level: Level = null, claims: HitClaims = null
) -> GameSession:
	var root: Node = TwoPeers.make_side(parent, side_name)
	var session: Session = Session.new()
	session.name = "GameSession"
	session.rng.seed = SEED
	_add_scene_children(session)
	session.match_end = MatchEnd.new()
	session.match_end.session = session
	session.add_child(session.match_end)
	session.level = level if level else Level.new()
	session.level.name = "Level"
	session.add_child(session.level)
	session.spawner = Spawner.new()
	session.spawner.name = "Enemies"
	session.spawner.session = session
	session.level.add_child(session.spawner)
	(session.get_node("WaveDirector") as WaveDirector).spawner = session.spawner
	session.hit_claims = claims
	_add_systems(session, parts)
	session.players = PlayerSpawner.new()
	session.players.name = "PlayerSpawner"
	session.players.player_scene = PLAYER
	session.players._parent = session.level
	session.add_child(session.players)
	root.add_child(session)
	session.set_physics_process(false)
	session.set_process_unhandled_input(false)
	session.match_end.setup()
	if session.loot:
		(session.hud.get_node("Root/Pack") as PackOverlay).setup(session.loot)
	return session


## Starts the PlayerSpawner the way _setup_level() does, at the origin. Call after host / join.
static func start_players(session: GameSession) -> void:
	session.players.setup(session.level, Transform3D.IDENTITY)


## Adds a player for peer_id by hand (no PlayerSpawner replication), physics off.
static func add_player(session: GameSession, peer_id: int) -> Player:
	var player: Player = PLAYER.instantiate() as Player
	player.name = str(peer_id)
	player.net_id = peer_id
	player.session = session
	player.set_multiplayer_authority(peer_id)
	session.level.add_child(player)
	player.set_physics_process(false)
	return player


## The players in the side's level.
static func players(session: GameSession) -> Array[Player]:
	var out: Array[Player] = []
	for child: Node in session.level.get_children():
		if child is Player:
			out.append(child as Player)
	return out


## A zombie spawn marker that only this side's Spawner uses.
static func add_spawn_point(session: GameSession, at: Vector3 = Vector3.ZERO) -> Marker3D:
	var group: StringName = StringName("coop_side_spawn_%d" % session.get_instance_id())
	session.spawner.spawn_group = group
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(group)
	marker.position = at
	session.level.add_child(marker)
	return marker


## Closes the side's peer and frees it. Close clients before the server.
static func close(session: GameSession) -> void:
	TwoPeers.close_side(session.get_parent())


static func _add_scene_children(session: GameSession) -> void:
	var director: WaveDirector = WaveDirector.new()
	director.rules = WAVES
	director.session = session
	var economy: Economy = Economy.new()
	economy.rules = ECONOMY
	var drops: PowerUpDrops = PowerUpDrops.new()
	drops.session = session
	economy.drops = drops
	var children: Dictionary[StringName, Node] = {
		&"WaveDirector": director,
		&"Economy": economy,
		&"Progression": ProgressionService.new(),
		&"PowerUpDrops": drops,
		&"Hud": HUD.instantiate(),
	}
	for node_name: StringName in children:
		children[node_name].name = node_name
		session.add_child(children[node_name])


static func _add_systems(session: GameSession, parts: Array[StringName]) -> void:
	if parts.has(&"hit_claims") and session.hit_claims == null:
		session.hit_claims = HitClaims.new()
	if session.hit_claims:
		session.hit_claims.name = "HitClaims"
	if parts.has(&"loot"):
		session.loot = LootService.new()
	if parts.has(&"remote_shots"):
		session.remote_shots = RemoteShots.new()
		session.remote_shots.name = "RemoteShots"
	if parts.has(&"interactions"):
		session.interactions = InteractionSync.new()
	if parts.has(&"deploy_vote"):
		session.deploy_vote = DeployVote.new()
	var wells: WellClaims = WellClaims.new() if parts.has(&"well_claims") else null
	var systems: Array[Node] = [
		session.hit_claims, wells, session.loot, session.remote_shots, session.interactions, session.deploy_vote
	]
	for system: Node in systems:
		if system:
			system.set("session", session)
			session.add_child(system)

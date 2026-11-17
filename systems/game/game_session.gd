## One match: owns map, players, rules, RNG and tick counter, and wires session systems.
class_name GameSession
extends Node

@export var level_scene: PackedScene
@export var player_scene: PackedScene
@export var starting_loadout: Array[WeaponData] = []
@export var wave_rules: WaveRules
@export var economy_rules: EconomyRules
## 0 = random seed each match.
@export var rng_seed: int = 0
@export var restart_delay: float = 2.5
## Empty disables local character persistence for tests and tools.
@export var profile_id: StringName = &"solo"
## False on a dedicated server, which has no player of its own.
@export var has_local_player: bool = true

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tick: int = 0
var level: Level
var spawner: Spawner
var players: PlayerSpawner
var handshake: Handshake
var look_sync: LookSync
var hit_claims: HitClaims
var interactions: InteractionSync
var loot: LootService
var remote_shots: RemoteShots
var is_over: bool = false
var _kills: int = 0
var _headshots: int = 0
var _profile: CharacterProfile
var _start_total_xp: int = 0
var _xp_banked: bool = false
var _profile_player: Player
var _quitting: bool = false
var _auto_accept_quit: bool = true
var _connection_lost: bool = false
var _match_stats: Dictionary = {}

@onready var director: WaveDirector = $WaveDirector
@onready var economy: Economy = $Economy
@onready var progression: ProgressionService = $Progression
@onready var power_up_drops: PowerUpDrops = $PowerUpDrops
@onready var hud: Hud = $Hud


func _ready() -> void:
	add_to_group(&"game_session")
	if rng_seed == 0:
		rng.randomize()
	else:
		rng.seed = rng_seed
	Net.reset_ids()
	economy.rules = economy_rules
	director.rules = wave_rules
	director.session = self
	power_up_drops.session = self
	if has_local_player and not profile_id.is_empty():
		_profile = CharacterProfile.load_or_create(profile_id)
		_start_total_xp = _profile.total_xp
	progression.run_xp_finalized.connect(bank_run_xp)
	Events.player_died.connect(_on_player_died)
	Events.enemy_killed.connect(_on_enemy_killed)
	_setup_handshake()
	if not _setup_network():
		return
	_auto_accept_quit = get_tree().auto_accept_quit
	if Net.is_online():
		get_tree().auto_accept_quit = false
	_setup_level()


func _setup_handshake() -> void:
	handshake = Handshake.new()
	handshake.name = "Handshake"
	handshake.has_local_player = has_local_player
	handshake.max_players = Net.player_limit
	add_child(handshake)
	handshake.setup(_profile.display_name if _profile else "Survivor", _profile.level if _profile else 1)


func _setup_level() -> void:
	level = level_scene.instantiate() as Level
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	spawner = Spawner.new()
	spawner.name = "Enemies"
	spawner.session = self
	level.add_child(spawner)
	director.spawner = spawner
	_setup_shooting()

	players = PlayerSpawner.new()
	players.name = "PlayerSpawner"
	players.player_scene = player_scene
	players.spawn_local = has_local_player
	add_child(players)
	look_sync = LookSync.new()
	look_sync.name = "LookSync"
	add_child(look_sync)
	look_sync.setup(players)
	players.player_added.connect(_on_player_added)
	if not level.is_navigation_ready:
		level.navigation_ready.connect(_try_start, CONNECT_ONE_SHOT)
	players.setup(level, level.get_player_spawn())


func _setup_network() -> bool:
	var join_error: Error = Net.start_pending_join()
	if join_error != OK:
		Log.warn(&"net", &"join_failed", {"error": error_string(join_error)})
		_on_connection_lost()
		return false
	multiplayer.server_disconnected.connect(_on_connection_lost, CONNECT_DEFERRED)
	multiplayer.connection_failed.connect(_on_connection_lost, CONNECT_DEFERRED)
	multiplayer.peer_authentication_failed.connect(_on_authentication_failed, CONNECT_DEFERRED)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	return true


func _setup_shooting() -> void:
	hit_claims = HitClaims.new()
	hit_claims.name = "HitClaims"
	loot = LootService.new()
	remote_shots = RemoteShots.new()
	remote_shots.name = "RemoteShots"
	interactions = InteractionSync.new()
	for system: Node in [hit_claims, loot, remote_shots, interactions]:
		system.set("session", self)
		add_child(system)
	(hud.get_node("Root/Pack") as PackOverlay).setup(loot)


func _physics_process(_delta: float) -> void:
	if not get_tree().paused and not is_over:
		tick += 1


func _exit_tree() -> void:
	get_tree().auto_accept_quit = _auto_accept_quit
	if has_local_player:
		Net.leave()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		bank_run_xp()
		if Net.is_online():
			quit_game()


func _on_player_added(player: Player) -> void:
	if player.is_multiplayer_authority():
		progression.set_start_total(player, _start_total_xp)
		_profile_player = player
		loot.player = player
	player.spawn(self, starting_loadout)
	if player == _profile_player and _profile:
		var loadout: Variant = _profile.to_dict().get("loadout", {})
		if loadout is Dictionary:
			ItemLoadout.apply(player, loadout)
		player.state_sync.send_loadout()
	if player.is_multiplayer_authority():
		player.gear_rig.apply(LookBuilder.from_equipped(_profile.loadout if _profile else {}))
	if is_over and multiplayer.is_server():
		_receive_match_end.rpc_id(player.net_id, _match_stats)
	remote_shots.watch_player(player)
	_try_start()


## Waves start once the navmesh is baked and someone is playing.
func _try_start() -> void:
	if is_over or not multiplayer.is_server():
		return
	if director.phase == WaveDirector.Phase.IDLE and level.is_navigation_ready and not get_players().is_empty():
		director.start()


func _on_connection_lost() -> void:
	if _connection_lost or not is_inside_tree():
		return
	_connection_lost = true
	Log.warn(&"net", &"connection_lost", {})
	bank_run_xp()
	Net.leave()
	if get_tree().current_scene == self:
		UI.replace(&"main_menu")


func _on_authentication_failed(peer_id: int) -> void:
	if peer_id == 1:
		_on_connection_lost()


func get_players() -> Array[Player]:
	var out: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if player.session != self or player.is_queued_for_deletion():
			continue
		if multiplayer.is_server() and player.net_id != 1 and not multiplayer.get_peers().has(player.net_id):
			continue
		out.append(player)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not is_over:
		_set_paused(not get_tree().paused)
	elif event.is_action_pressed(&"restart") and is_over:
		restart()


func _set_paused(value: bool) -> void:
	get_tree().paused = value
	UI.hold_mouse(hud.pause_panel, value)
	hud.show_paused(value)


func resume() -> void:
	if not is_over:
		_set_paused(false)


func restart() -> void:
	bank_run_xp()
	get_tree().paused = false
	UI.reload()


func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	bank_run_xp()
	await progression.wait_for_run_grants()
	get_tree().quit()


## All match exits share this guard, including a restart after game over.
func bank_run_xp() -> void:
	if _xp_banked:
		return
	_xp_banked = true
	var transport: MultiplayerPeer = progression.multiplayer.multiplayer_peer
	if (
		is_inside_tree()
		and transport
		and transport.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
		and progression.multiplayer.is_server()
	):
		for player: Player in get_players():
			progression.finish_run(player)
		var peer: ENetMultiplayerPeer = progression.multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if peer:
			peer.host.flush()
	if not has_local_player or _profile == null or not is_instance_valid(_profile_player):
		return
	_profile.total_xp += progression.get_xp(_profile_player)
	loot.bank(_profile)
	_profile.save()


## Ends the match as a successful exfil: +50% XP for the whole run.
func finish_exfil() -> void:
	if is_over or not multiplayer.is_server():
		return
	for player: Player in get_players():
		progression.add_xp(player, progression.get_xp(player) / 2)
	level.process_mode = Node.PROCESS_MODE_DISABLED
	_end_match(true)


func _on_enemy_killed(_enemy: Node3D, info: DamageInfo) -> void:
	_kills += 1
	if info.is_headshot():
		_headshots += 1


func _on_player_died(player: Player) -> void:
	if player.session == self:
		check_squad()


func _on_peer_left(_peer_id: int) -> void:
	check_squad.call_deferred()


## Only connected squad members count; an empty dedicated server waits for players.
func check_squad() -> void:
	if is_over or not multiplayer.is_server():
		return
	var squad: Array[Player] = get_players()
	if squad.is_empty():
		return
	for player: Player in squad:
		if player.is_alive():
			return
	_end_match(false)


func _end_match(exfiled: bool) -> void:
	if is_over or not multiplayer.is_server():
		return
	bank_run_xp()
	var squad: Array[Player] = get_players()
	var player: Player = squad[0] if not squad.is_empty() else null
	var stats: Dictionary = {
		"round": director.round_number,
		"kills": _kills,
		"headshots": _headshots,
		"points": player.wallet.points if player else 0,
		"exfil": exfiled,
	}
	if not multiplayer.get_peers().is_empty():
		_receive_match_end.rpc(stats)
	else:
		_receive_match_end(stats)


@rpc("authority", "call_local", "reliable")
func _receive_match_end(stats: Dictionary) -> void:
	if is_over:
		return
	is_over = true
	bank_run_xp()
	_match_stats = stats.duplicate()
	_match_stats.merge(loot.results(), true)
	if is_instance_valid(_profile_player):
		_match_stats["xp"] = progression.get_xp(_profile_player)
		_match_stats["start_total_xp"] = _start_total_xp
		_match_stats["total_xp"] = progression.get_total_xp(_profile_player)
	director.stop()
	if not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		level.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(restart_delay).timeout
	Events.game_over.emit(_match_stats)

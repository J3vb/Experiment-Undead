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
## The hub: no waves start, and the deploy vote can send everyone to a match.
@export var is_hub: bool = false

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tick: int = 0
var level: Level
var spawner: Spawner
var players: PlayerSpawner
var handshake: Handshake
var look_sync: LookSync
var hit_claims: HitClaims
var legendary_traits: LegendaryTraits
var interactions: InteractionSync
var loot: LootService
var remote_shots: RemoteShots
var deploy_vote: DeployVote
var match_end: MatchEnd
var is_over: bool = false
## The local character; null on a dedicated server or with no profile_id.
var profile: CharacterProfile
var profile_player: Player
var start_total_xp: int = 0
var _quitting: bool = false
var _auto_accept_quit: bool = true
var _connection_lost: bool = false

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
	economy.drops = power_up_drops
	if has_local_player and not profile_id.is_empty():
		profile = CharacterProfile.load_or_create(profile_id)
		start_total_xp = profile.total_xp
	match_end = MatchEnd.new()
	match_end.session = self
	add_child(match_end)
	match_end.setup()
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
	handshake.setup(profile.display_name if profile else "Survivor", profile.level if profile else 1)


func _setup_level() -> void:
	level = level_scene.instantiate() as Level
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	if not Build.is_server():
		level.add_child(ShaderWarmUp.new())
	spawner = Spawner.new()
	spawner.name = "Enemies"
	spawner.session = self
	level.add_child(spawner)
	director.spawner = spawner
	power_up_drops.setup(level)
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
	return true


func _setup_shooting() -> void:
	hit_claims = HitClaims.new()
	hit_claims.name = "HitClaims"
	legendary_traits = LegendaryTraits.new()
	legendary_traits.name = "LegendaryTraits"
	loot = LootService.new()
	remote_shots = RemoteShots.new()
	remote_shots.name = "RemoteShots"
	interactions = InteractionSync.new()
	deploy_vote = DeployVote.new()
	for system: Node in [
		hit_claims,
		legendary_traits,
		WellClaims.new(),
		GrenadeClaims.new(),
		AbilityClaims.new(),
		loot,
		remote_shots,
		interactions,
		deploy_vote,
	]:
		system.set("session", self)
		add_child(system)
	(hud.get_node("Root/Pack") as PackOverlay).setup(loot)


func _physics_process(_delta: float) -> void:
	if not get_tree().paused and not is_over:
		tick += 1


func _exit_tree() -> void:
	get_tree().auto_accept_quit = _auto_accept_quit
	while has_local_player and UI.top() != &"":
		UI.pop()
	if has_local_player:
		Net.leave()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		match_end.bank_run_xp()
		if Net.is_online():
			quit_game()


func _on_player_added(player: Player) -> void:
	if player.is_multiplayer_authority():
		progression.set_start_total(player, start_total_xp)
		player.abilities.ability = FieldAbility.pick_for_level(progression.get_level(player))
		profile_player = player
		loot.player = player
	var named: bool = not multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	player.display_name = handshake.player_name(player.net_id) if named else ""
	player.spawn(self, starting_loadout)
	if player == profile_player and profile:
		player.skill_ranks = SkillEffects.ranks_from(profile.skill_ranks)
		var loadout: Variant = profile.to_dict().get("loadout", {})
		if loadout is Dictionary:
			ItemLoadout.apply(player, loadout)
		player.loadout_sync.send_loadout()
	if player.is_multiplayer_authority():
		player.gear_rig.apply(LookBuilder.from_equipped(profile.loadout if profile else {}))
	match_end.share_results(player.net_id)
	remote_shots.watch_player(player)
	_try_start()


## Waves start once the navmesh is baked and someone is playing.
func _try_start() -> void:
	if is_over or is_hub or not multiplayer.is_server():
		return
	if director.phase == WaveDirector.Phase.IDLE and level.is_navigation_ready and not get_players().is_empty():
		director.start()


func _on_connection_lost() -> void:
	if _connection_lost or Net.changing_place or not is_inside_tree():
		return
	_connection_lost = true
	Log.warn(&"net", &"connection_lost", {})
	match_end.bank_run_xp()
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


## Esc opens pause only with no screen open; an open screen handles Esc itself.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not is_over and has_local_player and UI.top() == &"":
		var pause: PauseScreen = UI.push(&"pause") as PauseScreen
		pause.main_menu_requested.connect(return_to_menu)
		pause.quit_requested.connect(quit_game)
	elif event.is_action_pressed(&"restart") and is_over:
		get_viewport().set_input_as_handled()
		restart()


func return_to_menu() -> void:
	match_end.bank_run_xp()
	UI.replace(&"main_menu")


## Solo plays again; in co-op the squad goes back to the hub.
func restart() -> void:
	match_end.bank_run_xp()
	get_tree().paused = false
	(deploy_vote.back_to_hub if Net.is_coop(multiplayer) or Net.changing_place else Net.world.reload).call()


## exit_code 3 tells the launcher or Docker runner to restart on a newer version.
func quit_game(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	match_end.bank_run_xp()
	await progression.wait_for_run_grants()
	get_tree().quit(exit_code)

## One match. Owns the map, players, rules, RNG and tick counter, and wires
## the session systems together. Built from MapData-style exports.
class_name GameSession
extends Node

const MENU_SCENE: String = "res://systems/ui/main_menu.tscn"

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
var hit_claims: HitClaims
var remote_shots: RemoteShots
var is_over: bool = false
var _kills: int = 0
var _headshots: int = 0
var _profile: CharacterProfile
var _start_total_xp: int = 0
var _xp_banked: bool = false
var _profile_player: Player

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
	if not profile_id.is_empty():
		_profile = CharacterProfile.load_or_create(profile_id)
		_start_total_xp = _profile.total_xp
	Events.player_died.connect(_on_player_died)
	Events.enemy_killed.connect(_on_enemy_killed)

	var join_error: Error = Net.start_pending_join()
	if join_error != OK:
		Log.warn(&"net", &"join_failed", {"error": error_string(join_error)})
		_on_connection_lost()
		return
	multiplayer.server_disconnected.connect(_on_connection_lost)
	multiplayer.connection_failed.connect(_on_connection_lost)

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
	players.player_added.connect(_on_player_added)
	add_child(players)
	if not level.is_navigation_ready:
		level.navigation_ready.connect(_try_start, CONNECT_ONE_SHOT)
	players.setup(level, level.get_player_spawn())
	_capture_mouse(true)


func _setup_shooting() -> void:
	hit_claims = HitClaims.new()
	hit_claims.name = "HitClaims"
	hit_claims.session = self
	add_child(hit_claims)
	remote_shots = RemoteShots.new()
	remote_shots.name = "RemoteShots"
	remote_shots.session = self
	add_child(remote_shots)


func _physics_process(_delta: float) -> void:
	if not get_tree().paused:
		tick += 1


func _exit_tree() -> void:
	if has_local_player:
		Net.leave()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		bank_run_xp()


func _on_player_added(player: Player) -> void:
	if player.is_multiplayer_authority():
		progression.set_start_total(player, _start_total_xp)
		_profile_player = player
	player.spawn(self, starting_loadout)
	if player == _profile_player and _profile:
		var loadout: Variant = _profile.to_dict().get("loadout", {})
		if loadout is Dictionary:
			ItemLoadout.apply(player, loadout)
	remote_shots.watch_player(player)
	_try_start()


## Waves start once the navmesh is baked and someone is playing.
func _try_start() -> void:
	if is_over:
		return
	if director.phase == WaveDirector.Phase.IDLE and level.is_navigation_ready and not get_players().is_empty():
		director.start()


func _on_connection_lost() -> void:
	Log.warn(&"net", &"connection_lost", {})
	Net.leave()
	if get_tree().current_scene == self:
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU_SCENE)


func get_players() -> Array[Player]:
	var out: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		out.append(node as Player)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not is_over:
		_set_paused(not get_tree().paused)
	elif event.is_action_pressed(&"restart") and is_over:
		restart()
	elif event is InputEventMouseButton and event.is_pressed() and not get_tree().paused and not is_over:
		_capture_mouse(true)


func _set_paused(value: bool) -> void:
	get_tree().paused = value
	_capture_mouse(not value)
	hud.show_paused(value)


func resume() -> void:
	if not is_over:
		_set_paused(false)


func restart() -> void:
	bank_run_xp()
	get_tree().paused = false
	get_tree().reload_current_scene()


func quit_game() -> void:
	bank_run_xp()
	get_tree().quit()


## All match exits share this guard, including a restart after game over.
func bank_run_xp() -> void:
	if _xp_banked or not Net.is_authority():
		return
	_xp_banked = true
	if _profile == null or not is_instance_valid(_profile_player):
		return
	_profile.total_xp += progression.get_xp(_profile_player)
	_profile.save()


## Ends the match as a successful exfil: +50% XP for the whole run.
func finish_exfil() -> void:
	if is_over:
		return
	for player: Player in get_players():
		progression.add_xp(player, progression.get_xp(player) / 2)
	level.process_mode = Node.PROCESS_MODE_DISABLED
	_end_match(true)


func _on_enemy_killed(_enemy: Node3D, info: DamageInfo) -> void:
	_kills += 1
	if info.is_headshot():
		_headshots += 1


func _on_player_died(_player: Player) -> void:
	for p: Player in get_players():
		if p.is_alive():
			return
	_end_match(false)


func _end_match(exfiled: bool) -> void:
	if is_over:
		return
	is_over = true
	director.stop()
	bank_run_xp()
	var stats: Dictionary = {
		"round": director.round_number,
		"kills": _kills,
		"headshots": _headshots,
		"points": get_players()[0].wallet.points if not get_players().is_empty() else 0,
		"xp": progression.get_xp(get_players()[0]) if not get_players().is_empty() else 0,
		"exfil": exfiled,
		"start_total_xp": _start_total_xp,
		"total_xp": progression.get_total_xp(_profile_player),
	}
	await get_tree().create_timer(restart_delay).timeout
	_capture_mouse(false)
	Events.game_over.emit(stats)


func _capture_mouse(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

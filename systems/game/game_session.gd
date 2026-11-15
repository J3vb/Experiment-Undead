## One match. Owns the map, players, rules, RNG and tick counter, and wires
## the session systems together. Built from MapData-style exports.
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

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tick: int = 0
var level: Level
var spawner: Spawner
var is_over: bool = false
var _kills: int = 0
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
	rng.seed = rng_seed if rng_seed != 0 else randi()
	Net.reset_ids()
	economy.rules = economy_rules
	director.rules = wave_rules
	director.session = self
	power_up_drops.session = self
	if not profile_id.is_empty():
		_profile = CharacterProfile.load_or_create(profile_id)
		_start_total_xp = _profile.total_xp
	Events.player_died.connect(_on_player_died)
	Events.enemy_killed.connect(func(_e: Node3D, _i: DamageInfo) -> void: _kills += 1)

	level = level_scene.instantiate() as Level
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	spawner = Spawner.new()
	spawner.name = "Enemies"
	spawner.session = self
	level.add_child(spawner)
	director.spawner = spawner

	_spawn_player()
	if level.is_navigation_ready:
		director.start()
	else:
		level.navigation_ready.connect(director.start, CONNECT_ONE_SHOT)
	_capture_mouse(true)


func _physics_process(_delta: float) -> void:
	if not get_tree().paused:
		tick += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		bank_run_xp()


func _spawn_player() -> Player:
	var player: Player = player_scene.instantiate() as Player
	player.net_id = Net.allocate_id()
	level.add_child(player)
	player.global_transform = level.get_player_spawn()
	progression.set_start_total(player, _start_total_xp)
	player.spawn(self, starting_loadout)
	_profile_player = player
	return player


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

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

@onready var director: WaveDirector = $WaveDirector
@onready var economy: Economy = $Economy
@onready var progression: ProgressionService = $Progression
@onready var power_up_drops: PowerUpDrops = $PowerUpDrops
@onready var hud: Hud = $Hud

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tick: int = 0
var level: Level
var spawner: Spawner
var is_over: bool = false
var _kills: int = 0


func _ready() -> void:
	add_to_group(&"game_session")
	rng.seed = rng_seed if rng_seed != 0 else randi()
	Net.reset_ids()
	economy.rules = economy_rules
	director.rules = wave_rules
	director.session = self
	power_up_drops.session = self
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


func _spawn_player() -> Player:
	var player: Player = player_scene.instantiate() as Player
	player.net_id = Net.allocate_id()
	level.add_child(player)
	player.global_transform = level.get_player_spawn()
	player.spawn(self, starting_loadout)
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


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_player_died(_player: Player) -> void:
	for p: Player in get_players():
		if p.is_alive():
			return
	is_over = true
	director.stop()
	var stats: Dictionary = {
		"round": director.round_number,
		"kills": _kills,
		"points": get_players()[0].wallet.points if not get_players().is_empty() else 0,
		"xp": progression.get_xp(get_players()[0]) if not get_players().is_empty() else 0,
	}
	await get_tree().create_timer(restart_delay).timeout
	_capture_mouse(false)
	Events.game_over.emit(stats)


func _capture_mouse(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

## Rolls a power-up drop for every zombie kill: drop_chance each, at most
## max_per_round a round. Types come from a shuffled deck, so every type drops
## once before any repeats. Kills by a player with Scavenger can also drop an
## ammo pack (not counted in the cap). Lives in the GameSession. The server
## spawns pickups through a MultiplayerSpawner, so every peer and late joiner
## sees them; effects reach the PCs that own the guns.
class_name PowerUpDrops
extends Node

const SCENE: PackedScene = preload("res://systems/power_ups/power_up.tscn")

@export var drop_chance: float = 0.01
@export var max_per_round: int = 1
@export var power_ups: Array[PowerUpData] = []
@export var ammo_pack: PowerUpData
@export var ammo_pack_chance: float = 0.05

var session: GameSession
var dropped_this_round: int = 0
var _deck: Array[PowerUpData] = []
var _net: MultiplayerSpawner
var _next_id: int = 0


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.round_started.connect(func(_round: int, _count: int) -> void: dropped_this_round = 0)


## Called once the level exists, on every peer, so spawns have the same path everywhere.
func setup(level: Node3D) -> void:
	_net = MultiplayerSpawner.new()
	_net.name = "Net"
	_net.spawn_function = _create
	add_child(_net)
	_net.spawn_path = _net.get_path_to(level)


func drop(data: PowerUpData, at: Vector3) -> PowerUp:
	dropped_this_round += 1
	return _spawn(data, at)


func _spawn(data: PowerUpData, at: Vector3) -> PowerUp:
	_next_id += 1
	var spawn_data: Array = [_next_id, data.id, at + Vector3.UP * 0.8]
	if _net:
		return _net.spawn(spawn_data) as PowerUp
	var pickup: PowerUp = _create(spawn_data) as PowerUp
	session.level.add_child(pickup)
	return pickup


## Runs on the server and on every client with the same data.
func _create(spawn_data: Array) -> Node:
	var pickup: PowerUp = SCENE.instantiate() as PowerUp
	pickup.name = "PowerUp%d" % int(spawn_data[0])
	pickup.data = Content.get_item(&"power_ups", spawn_data[1]) as PowerUpData
	pickup.drops = self
	pickup.position = spawn_data[2]
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(^".:age")
	config.property_set_replication_mode(^".:age", SceneReplicationConfig.REPLICATION_MODE_NEVER)
	sync.replication_config = config
	pickup.add_child(sync)
	return pickup


## Server: the effect goes to every PC whose guns it changes, then everyone hears and sees it.
func on_collected(pickup: PowerUp, collector: Player) -> void:
	var targets: Array[Player] = [collector]
	if pickup.data.effect == PowerUpData.Effect.RESUPPLY:
		targets = session.get_players()
	for player: Player in targets:
		if pickup.data.effect == PowerUpData.Effect.RESUPPLY:
			player.grenades.refill()
		if player.net_id == multiplayer.get_unique_id():
			PowerUp.apply_effect(player, pickup.data)
		elif multiplayer.get_peers().has(player.net_id):
			_receive_effect.rpc_id(player.net_id, pickup.data.id)
	if not multiplayer.get_peers().is_empty():
		_receive_collected.rpc(pickup.name, pickup.data.id, collector.net_id)


@rpc("authority", "call_remote", "reliable")
func _receive_effect(data_id: StringName) -> void:
	var data: PowerUpData = Content.get_item(&"power_ups", data_id) as PowerUpData
	var player: Player = session.players.find_player(multiplayer.get_unique_id()) if session.players else null
	if data and player:
		PowerUp.apply_effect(player, data)


@rpc("authority", "call_remote", "reliable")
func _receive_collected(pickup_name: String, data_id: StringName, collector_id: int) -> void:
	var data: PowerUpData = Content.get_item(&"power_ups", data_id) as PowerUpData
	if data == null:
		return
	var pickup: PowerUp = session.level.get_node_or_null(pickup_name) as PowerUp
	if pickup:
		pickup.play_collect_sound()
		pickup.hide()
	Events.power_up_collected.emit(session.players.find_player(collector_id) if session.players else null, data)


func _on_enemy_killed(enemy: Node3D, info: DamageInfo) -> void:
	if not multiplayer.is_server():
		return
	var killer: Player = info.attacker as Player
	if killer and killer.has_serum(&"scavenger") and session.rng.randf() < ammo_pack_chance:
		_spawn(ammo_pack, enemy.global_position)
	if dropped_this_round >= max_per_round or power_ups.is_empty():
		return
	if session.rng.randf() < drop_chance:
		drop(_next(), enemy.global_position)


func _next() -> PowerUpData:
	if _deck.is_empty():
		_deck = power_ups.duplicate()
		for i: int in range(_deck.size() - 1, 0, -1):
			var j: int = session.rng.randi_range(0, i)
			var swap: PowerUpData = _deck[i]
			_deck[i] = _deck[j]
			_deck[j] = swap
	return _deck.pop_back()

## Owns each player's run XP and starting total, and announces newly reached levels.
class_name ProgressionService
extends Node

signal xp_gained(player: Player, amount: int, total: int)
signal run_xp_finalized

@export var rules: XpRules = preload("res://content/progression/xp_rules.tres")

var _xp: Dictionary[Player, int] = {}
var _start_total: Dictionary[Player, int] = {}
var _finished: Dictionary[Player, bool] = {}
var _final_received: bool = false
var _pending_grants: Dictionary[int, bool] = {}


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.round_ended.connect(_on_round_ended)
	multiplayer.peer_disconnected.connect(func(peer_id: int) -> void: _pending_grants.erase(peer_id))


func add_xp(player: Player, amount: int) -> void:
	if not _is_authority() or amount <= 0 or _finished.has(player):
		return
	var previous_level: int = get_level(player)
	_xp[player] = _xp.get(player, 0) + amount
	var new_level: int = get_level(player)
	xp_gained.emit(player, amount, _xp[player])
	for level: int in range(previous_level + 1, new_level + 1):
		Events.player_leveled_up.emit(player, level)
	if not is_inside_tree():
		return
	var owner_id: int = player.get_multiplayer_authority()
	if owner_id != multiplayer.get_unique_id() and multiplayer.get_peers().has(owner_id):
		_receive_run_xp.rpc_id(owner_id, _xp[player], false)


func get_xp(player: Player) -> int:
	return _xp.get(player, 0)


func set_start_total(player: Player, total: int) -> void:
	if not _is_authority():
		if player.multiplayer != multiplayer or not player.is_multiplayer_authority():
			return
	_start_total[player] = maxi(total, 0)


func get_total_xp(player: Player) -> int:
	return _start_total.get(player, 0) + get_xp(player)


func get_level(player: Player) -> int:
	return rules.level_for_total_xp(get_total_xp(player))


## Final totals go only to the character's owner. Repeated exits never grant twice.
func finish_run(player: Player) -> void:
	if not _is_authority() or _finished.has(player):
		return
	_finished[player] = true
	if not is_inside_tree():
		return
	var owner_id: int = player.get_multiplayer_authority()
	if owner_id != multiplayer.get_unique_id() and multiplayer.get_peers().has(owner_id):
		_pending_grants[owner_id] = true
		_receive_run_xp.rpc_id(owner_id, get_xp(player), true)


## Let final reliable grants reach their owners before the server closes its port.
func wait_for_run_grants() -> void:
	if _pending_grants.is_empty():
		return
	var timeout: SceneTreeTimer = get_tree().create_timer(1.0, true)
	while not _pending_grants.is_empty() and timeout.time_left > 0.0:
		await get_tree().process_frame


@rpc("any_peer", "call_remote", "reliable")
func _acknowledge_run_xp() -> void:
	if _is_authority():
		_pending_grants.erase(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _receive_run_xp(total: int, final: bool) -> void:
	if _is_authority() or multiplayer.get_remote_sender_id() != 1 or total < 0 or _final_received:
		return
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if player == null or player.multiplayer != multiplayer or not player.is_multiplayer_authority():
			continue
		var previous_level: int = get_level(player)
		var amount: int = total - get_xp(player)
		_xp[player] = total
		var new_level: int = get_level(player)
		if amount > 0:
			xp_gained.emit(player, amount, total)
		for level: int in range(previous_level + 1, new_level + 1):
			Events.player_leveled_up.emit(player, level)
		if final:
			_final_received = true
			run_xp_finalized.emit()
			_acknowledge_run_xp.rpc_id(1)
		return


func _on_enemy_killed(enemy: Node3D, info: DamageInfo) -> void:
	var player: Player = info.attacker as Player
	var zombie: Zombie = enemy as Zombie
	if player and zombie and zombie.data:
		var amount: int = zombie.data.xp_reward
		if info.is_headshot():
			amount += rules.headshot_kill_bonus
		add_xp(player, amount)


func _on_round_ended(round_number: int) -> void:
	if not _is_authority():
		return
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if player and player.is_alive():
			add_xp(player, rules.round_clear_xp_per_round * round_number)


func _is_authority() -> bool:
	if not is_inside_tree():
		return Net.is_authority()
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return true
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED and multiplayer.is_server()

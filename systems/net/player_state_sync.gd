## Server-owned player vitality and co-op life cycle; clients only present snapshots.
class_name PlayerStateSync
extends Node

const BLEED_OUT_TIME: float = 30.0
const PISTOL: StringName = &"pistol_service"

var bleed_left: float = 0.0
var _player: Player
var _initial_spawn: Transform3D
var _publish_queued: bool = false
var _icon: Label3D
var _spectating: Player
var _standing_weapon: Weapon
var _downed_sidearm: Weapon
var _sidearm_selected: bool = false


func _init() -> void:
	name = "PlayerStateSync"
	set_multiplayer_authority(1)


func _ready() -> void:
	_player = get_parent() as Player
	_initial_spawn = _player.transform
	_player.wallet.points_changed.connect(_points_changed)
	Events.serum_gained.connect(_serum_gained)
	Events.round_started.connect(_on_round_started)
	Events.enemy_damaged.connect(_on_enemy_damaged)
	_icon = Label3D.new()
	_icon.text = "+"
	_icon.modulate = Color("c3201b")
	_icon.font_size = 96
	_icon.position.y = 2.2
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.visible = false
	_player.add_child(_icon)
	if not multiplayer.is_server():
		_request_snapshot.call_deferred()


func is_coop() -> bool:
	return Net.is_coop(multiplayer)


func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	if _player.session and _player.session.is_over:
		return
	if multiplayer.is_server():
		# Only a co-op down bleeds out: a solo Second Wind down (no bleed time) keeps the solo
		# rule even if a friend joins during it.
		if _player.is_downed and bleed_left > 0.0:
			bleed_left = maxf(bleed_left - delta, 0.0)
			if bleed_left <= 0.0:
				_player.is_downed = false
				_player.is_dead = true
				_present()
				publish()
				Events.player_died.emit(_player)
	elif _player.is_downed:
		bleed_left = maxf(bleed_left - delta, 0.0)
	if _player.is_multiplayer_authority() and _player.is_dead and is_coop():
		_spectate()


## Server: item on-hit effects for every hit this player lands, from any peer.
func _on_enemy_damaged(_enemy: Node3D, info: DamageInfo) -> void:
	if multiplayer.is_server() and info.attacker == _player and not info.item_uid.is_empty():
		var item: ItemInstance = _player.item_guns.get(info.item_uid)
		if item:
			ItemLoadout.apply_hit(_player, item, info)


func _points_changed(_total: int, _delta: int) -> void:
	queue_publish()


func _serum_gained(player: Player, _serum: SerumData) -> void:
	if player == _player:
		queue_publish()


func queue_publish() -> void:
	if not multiplayer.is_server() or _publish_queued:
		return
	_publish_queued = true
	publish.call_deferred()


func publish() -> void:
	_publish_queued = false
	if is_inside_tree() and multiplayer.is_server() and is_coop():
		_receive_state.rpc(_snapshot())


func _snapshot() -> Dictionary:
	var ids: Array[StringName] = []
	for serum: SerumData in _player.serums:
		ids.append(serum.id)
	return {
		"current": _player.health.current,
		"maximum": _player.health.max_health,
		"downed": _player.is_downed,
		"dead": _player.is_dead,
		"points": _player.wallet.points,
		"serums": ids,
		"name": _player.display_name,
		"bleed": bleed_left,
		"grenades": _player.grenades.count,
	}


func _request_snapshot() -> void:
	if not is_inside_tree():
		return
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if not multiplayer.is_server():
		_send_snapshot.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _send_snapshot() -> void:
	if multiplayer.is_server():
		_receive_state.rpc_id(multiplayer.get_remote_sender_id(), _snapshot())


@rpc("authority", "call_remote", "reliable")
func _receive_state(state: Dictionary) -> void:
	var was_downed: bool = _player.is_downed
	var was_dead: bool = _player.is_dead
	var damage: float = _player.health.current - float(state.current)
	_player.is_downed = state.downed
	_player.is_dead = state.dead
	_player.health.current = state.current
	_player.health.max_health = state.maximum
	_player.health.is_dead = _player.is_downed or _player.is_dead
	_player.wallet.set_points(state.points)
	_player.display_name = state.get("name", "")
	bleed_left = float(state.get("bleed", 0.0))
	_player.grenades.count = int(state.get("grenades", _player.grenades.count))
	_sync_serums(state.serums)
	_player.health.health_changed.emit(_player.health.current, _player.health.max_health)
	if damage > 0.0 and _player.is_multiplayer_authority():
		_player._on_damaged(DamageInfo.create(damage, null))
	_present()
	if was_downed and not _player.is_downed and not _player.is_dead:
		Events.player_revived.emit(_player)
	if not was_dead and _player.is_dead:
		Events.player_died.emit(_player)


func _sync_serums(ids: Array) -> void:
	for index: int in range(_player.serums.size() - 1, -1, -1):
		if not ids.has(_player.serums[index].id):
			_player.serums.remove_at(index)
	for id: StringName in ids:
		var serum: SerumData = Content.get_item(&"serums", id) as SerumData
		if serum and not _player.serums.has(serum):
			_player.serums.append(serum)
			Events.serum_gained.emit(_player, serum)
	_player.weapons.max_slots = roundi(2 * _player.get_stat(&"weapon_slots"))


## Server: down in co-op. Second Wind gets the player up after second_wind_time.
func down_player(second_wind: bool = false) -> void:
	if not multiplayer.is_server() or not is_coop():
		return
	_player.is_downed = true
	_player.is_dead = false
	bleed_left = BLEED_OUT_TIME
	if not second_wind:
		_player.lose_serums()
	_present()
	publish()
	if second_wind:
		_player.revive.second_wind()
	elif _player.session and _player.session.is_inside_tree():
		_player.session.match_end.check_squad()


func revive_player() -> void:
	if not multiplayer.is_server() or not _player.is_downed or _player.is_dead:
		return
	_player.is_downed = false
	bleed_left = 0.0
	_player.health.reset(_player.health.max_health)
	_present()
	publish()
	Events.player_revived.emit(_player)


func _on_round_started(_round_number: int, _count: int) -> void:
	if multiplayer.is_server() and is_coop() and _player.is_dead:
		respawn_player()


func respawn_player() -> void:
	if not multiplayer.is_server() or (_player.session and _player.session.is_over):
		return
	var spawn_point: Transform3D = _initial_spawn
	if _player.session and _player.session.level:
		spawn_point = _player.session.level.get_player_spawn()
	_respawn.rpc(spawn_point)
	_player.is_dead = false
	_player.is_downed = false
	bleed_left = 0.0
	_player.health.reset(_player.health.max_health)
	_present()
	publish()


@rpc("authority", "call_local", "reliable")
func _respawn(spawn_point: Transform3D) -> void:
	_restore_weapons()
	_player.teleport(spawn_point)
	for weapon: Weapon in _player.weapons.weapons:
		weapon.queue_free()
	_player.weapons.weapons.clear()
	_player.weapons.current = null
	_player.weapons.give(Content.weapon(PISTOL))


func _present() -> void:
	if not is_coop():
		return
	var local: bool = _player.is_multiplayer_authority()
	_player.visible = not _player.is_dead
	_player.collision_layer = 0 if _player.is_dead else Layers.PLAYER
	_player.collision_mask = 0 if _player.is_dead else Layers.WORLD | Layers.ENEMY | Layers.BARRIER
	_player.input_enabled = not _player.is_dead
	_player.weapons.visible = local and not _player.is_dead
	_player.camera_rig.tilt_down(_player.is_downed)
	_icon.visible = _player.is_downed and not local
	if _player.is_downed:
		_equip_sidearm()
	else:
		_restore_weapons()
	if local and not _player.is_dead:
		_spectating = null
		_player.camera.make_current()
	if _player.is_dead:
		_player.weapons.set_trigger(false)
		_player.move_input = Vector2.ZERO


func _equip_sidearm() -> void:
	if _sidearm_selected:
		return
	_sidearm_selected = true
	_standing_weapon = _player.weapons.current
	for index: int in _player.weapons.weapons.size():
		if _player.weapons.weapons[index].data.id == PISTOL:
			_player.weapons.equip(index)
			return
	var slots: int = _player.weapons.max_slots
	_player.weapons.max_slots = maxi(slots, _player.weapons.weapons.size() + 1)
	_downed_sidearm = _player.weapons.give(Content.weapon(PISTOL))
	_player.weapons.max_slots = slots


func _restore_weapons() -> void:
	if not _sidearm_selected:
		return
	_sidearm_selected = false
	if is_instance_valid(_downed_sidearm):
		_player.weapons.weapons.erase(_downed_sidearm)
		_downed_sidearm.set_active(false)
		_player.weapons.current = null
		_downed_sidearm.queue_free()
	_downed_sidearm = null
	if is_instance_valid(_standing_weapon):
		_player.weapons.equip(_player.weapons.weapons.find(_standing_weapon))
	_standing_weapon = null


func _spectate() -> void:
	if is_instance_valid(_spectating) and _spectating.is_alive():
		return
	_spectating = null
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var teammate: Player = node as Player
		if (
			teammate != _player
			and teammate.get_multiplayer() == multiplayer
			and teammate.session == _player.session
			and teammate.is_alive()
		):
			_spectating = teammate
			teammate.camera.make_current()
			return

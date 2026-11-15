## Relays one cosmetic packet per owner's shot, including every pellet endpoint.
class_name RemoteShots
extends Node

var session: GameSession

var _points: PackedVector3Array = PackedVector3Array()
var _muzzles: Dictionary[Weapon, Node3D] = {}
var _effects: Dictionary[Player, RemoteShotEffects] = {}
var _weapons: Dictionary[StringName, WeaponData] = {}
var _max_extra_pellets: int = 0


func _ready() -> void:
	for weapon_id: StringName in Content.ids(&"weapons"):
		_weapons[weapon_id] = Content.weapon(weapon_id)
	var pellets: AffixData = Content.get_item(&"loot", &"pellets") as AffixData
	if pellets:
		for tier: AffixTier in pellets.tiers:
			_max_extra_pellets = maxi(_max_extra_pellets, roundi(tier.high))


func watch_player(player: Player) -> void:
	if not player.is_multiplayer_authority():
		var effects: RemoteShotEffects = RemoteShotEffects.new()
		effects.name = "ShotEffects"
		player.add_child(effects)
		_effects[player] = effects
		player.tree_exiting.connect(func() -> void: _effects.erase(player), CONNECT_ONE_SHOT)
		return
	player.weapons.child_entered_tree.connect(_watch_new_weapon)
	for weapon: Weapon in player.weapons.weapons:
		_watch_weapon(weapon)


func _watch_new_weapon(node: Node) -> void:
	if node is Weapon:
		node.ready.connect(_watch_weapon.bind(node as Weapon), CONNECT_ONE_SHOT)


func _watch_weapon(weapon: Weapon) -> void:
	_muzzles[weapon] = weapon.find_child("Muzzle", true, false) as Node3D
	weapon.fired.connect(_on_fired.bind(weapon))
	weapon.tree_exiting.connect(func() -> void: _muzzles.erase(weapon), CONNECT_ONE_SHOT)


## Called from the trace so misses also produce a tracer out to maximum range.
func record_trace(weapon: Weapon, point: Vector3) -> void:
	if weapon.shooter.is_multiplayer_authority() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_points.append(point)


func _on_fired(weapon: Weapon) -> void:
	var points: PackedVector3Array = _points
	_points = PackedVector3Array()
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	var muzzle: Node3D = _muzzles.get(weapon)
	var origin: Vector3 = muzzle.global_position if muzzle else weapon.camera.global_position
	if multiplayer.is_server():
		_relay(weapon.shooter.net_id, weapon.data.id, origin, points)
	else:
		shot.rpc_id(1, weapon.data.id, origin, points)


@rpc("any_peer", "call_remote", "unreliable")
func shot(weapon_id: StringName, origin: Vector3, points: PackedVector3Array) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Player = session.players.find_player(sender)
	var data: WeaponData = _weapons.get(weapon_id)
	if player == null or not player.is_alive() or data == null:
		return
	if not _valid_pellet_count(data, points.size()) or not origin.is_finite():
		return
	for point: Vector3 in points:
		if not point.is_finite():
			return
	_relay(sender, weapon_id, origin, points)


func _valid_pellet_count(data: WeaponData, count: int) -> bool:
	var max_pellets: int = data.pellets + (_max_extra_pellets if data.loot_tags.has(&"shotgun") else 0)
	if count >= data.pellets and count <= max_pellets:
		return true
	return data.loot_tags.has(&"double") and count % 2 == 0 and count >= data.pellets * 2 and count <= max_pellets * 2


func _relay(peer_id: int, weapon_id: StringName, origin: Vector3, points: PackedVector3Array) -> void:
	_show(peer_id, weapon_id, origin, points)
	for recipient: int in multiplayer.get_peers():
		if recipient != peer_id:
			play_shot.rpc_id(recipient, peer_id, weapon_id, origin, points)


@rpc("authority", "call_remote", "unreliable")
func play_shot(peer_id: int, weapon_id: StringName, origin: Vector3, points: PackedVector3Array) -> void:
	_show(peer_id, weapon_id, origin, points)


func _show(peer_id: int, weapon_id: StringName, origin: Vector3, points: PackedVector3Array) -> void:
	var player: Player = session.players.find_player(peer_id)
	var effects: RemoteShotEffects = _effects.get(player)
	var data: WeaponData = _weapons.get(weapon_id)
	if effects and data:
		effects.play(data, origin, points)

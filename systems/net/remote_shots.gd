## Relays one cosmetic packet per owner's shot: every pellet endpoint for the
## tracers, plus every real hit (point and Impact.Kind) for the impacts.
class_name RemoteShots
extends Node

## Pierce stops long before this; more hits than this per pellet is a bad packet.
const MAX_HITS_PER_PELLET: int = 4

var session: GameSession

var _points: PackedVector3Array = PackedVector3Array()
var _hits: PackedVector3Array = PackedVector3Array()
var _kinds: PackedByteArray = PackedByteArray()
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
		effects.body = player.get_node_or_null(^"Body/BodyAnimator") as BodyAnimator
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
	weapon.traced.connect(_on_traced)
	weapon.tree_exiting.connect(func() -> void: _muzzles.erase(weapon), CONNECT_ONE_SHOT)


## Called from the trace so misses also produce a tracer out to maximum range.
func record_trace(weapon: Weapon, point: Vector3) -> void:
	if weapon.shooter.is_multiplayer_authority() and Net.is_coop(multiplayer):
		_points.append(point)


## Each real hit of the trace (misses emit nothing), with its kind decided by the shooter.
func _on_traced(point: Vector3, _normal: Vector3, kind: Impact.Kind) -> void:
	if Net.is_coop(multiplayer):
		_hits.append(point)
		_kinds.append(kind)


func _on_fired(weapon: Weapon) -> void:
	var points: PackedVector3Array = _points
	var hits: PackedVector3Array = _hits
	var kinds: PackedByteArray = _kinds
	_points = PackedVector3Array()
	_hits = PackedVector3Array()
	_kinds = PackedByteArray()
	if not Net.is_coop(multiplayer):
		return
	var muzzle: Node3D = _muzzles.get(weapon)
	var origin: Vector3 = muzzle.global_position if muzzle else weapon.camera.global_position
	if multiplayer.is_server():
		_relay(weapon.shooter.net_id, weapon.data.id, origin, points, hits, kinds)
	else:
		shot.rpc_id(1, weapon.data.id, origin, points, hits, kinds)


@rpc("any_peer", "call_remote", "unreliable")
func shot(
	weapon_id: StringName, origin: Vector3, points: PackedVector3Array, hits: PackedVector3Array, kinds: PackedByteArray
) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Player = session.players.find_player(sender)
	var data: WeaponData = _weapons.get(weapon_id)
	if (
		player == null
		or player.is_dead
		or not (player.is_alive() or player.is_downed)
		or session.is_over
		or (player.is_downed and weapon_id != PlayerStateSync.PISTOL)
		or data == null
	):
		return
	if not _valid_pellet_count(data, points.size()) or not origin.is_finite():
		return
	if not _valid_points(points) or not _valid_hits(points.size(), hits, kinds):
		return
	_relay(sender, weapon_id, origin, points, hits, kinds)


func _valid_points(points: PackedVector3Array) -> bool:
	for point: Vector3 in points:
		if not point.is_finite():
			return false
	return true


## One kind per hit, at most MAX_HITS_PER_PELLET hits per pellet, kinds are Impact.Kind values.
func _valid_hits(pellets: int, hits: PackedVector3Array, kinds: PackedByteArray) -> bool:
	if hits.size() != kinds.size() or hits.size() > pellets * MAX_HITS_PER_PELLET or not _valid_points(hits):
		return false
	for kind: int in kinds:
		if kind > Impact.Kind.HEAD:
			return false
	return true


func _valid_pellet_count(data: WeaponData, count: int) -> bool:
	var max_pellets: int = data.pellets + (_max_extra_pellets if data.loot_tags.has(&"shotgun") else 0)
	if count >= data.pellets and count <= max_pellets:
		return true
	return data.loot_tags.has(&"double") and count % 2 == 0 and count >= data.pellets * 2 and count <= max_pellets * 2


func _relay(
	peer_id: int,
	weapon_id: StringName,
	origin: Vector3,
	points: PackedVector3Array,
	hits: PackedVector3Array,
	kinds: PackedByteArray
) -> void:
	_show(peer_id, weapon_id, origin, points, hits, kinds)
	for recipient: int in multiplayer.get_peers():
		if recipient != peer_id:
			play_shot.rpc_id(recipient, peer_id, weapon_id, origin, points, hits, kinds)


@rpc("authority", "call_remote", "unreliable")
func play_shot(
	peer_id: int,
	weapon_id: StringName,
	origin: Vector3,
	points: PackedVector3Array,
	hits: PackedVector3Array,
	kinds: PackedByteArray
) -> void:
	_show(peer_id, weapon_id, origin, points, hits, kinds)


func _show(
	peer_id: int,
	weapon_id: StringName,
	origin: Vector3,
	points: PackedVector3Array,
	hits: PackedVector3Array,
	kinds: PackedByteArray
) -> void:
	var player: Player = session.players.find_player(peer_id)
	var effects: RemoteShotEffects = _effects.get(player)
	var data: WeaponData = _weapons.get(weapon_id)
	if effects and data:
		effects.play(data, origin, points)
		effects.show_hits(origin, hits, kinds)

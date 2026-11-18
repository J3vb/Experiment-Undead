## Gravity-well requests from trusted owners: the server checks the gun, range and
## rate, opens the real well and shows orbs and wells to everyone else.
## Shares the per-gun claim window, refusal warning and cached guns with HitClaims.
class_name WellClaims
extends Node

const FLIGHT_TIME: float = GravityWell.ORB_RANGE / GravityWell.ORB_SPEED + 1.0

var session: GameSession

var _time: float = 0.0
var _orb_claims: Dictionary[int, Array] = {}
var _well_launches: Dictionary[int, Array] = {}


func _init() -> void:
	name = "WellClaims"


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_forget_peer)


func _physics_process(delta: float) -> void:
	_time += delta


func _forget_peer(peer_id: int) -> void:
	_orb_claims.erase(peer_id)
	_well_launches.erase(peer_id)


func request_well(point: Vector3, weapon_id: StringName) -> void:
	if multiplayer.is_server():
		_accept_well(multiplayer.get_unique_id(), point, weapon_id)
	else:
		well_at.rpc_id(1, point, weapon_id)


@rpc("any_peer", "call_remote", "reliable")
func well_at(point: Vector3, weapon_id: StringName) -> void:
	if multiplayer.is_server():
		_accept_well(multiplayer.get_remote_sender_id(), point, weapon_id)


## The server's own copy of a WELL gun, or null when the id names any other gun.
func _well_weapon(weapon_id: StringName) -> WeaponData:
	var data: WeaponData = session.hit_claims.cached_weapon(weapon_id)
	return data if data and data.effect == WeaponData.Effect.WELL else null


func _accept_well(peer_id: int, point: Vector3, weapon_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	var claims: HitClaims = session.hit_claims
	var data: WeaponData = _well_weapon(weapon_id)
	if data == null:
		claims.reject(peer_id, &"well_wrong_weapon")
		return
	var player: Player = session.players.find_player(peer_id)
	if player == null or not player.is_alive() or not point.is_finite():
		claims.reject(peer_id, &"well_out_of_bounds")
		return
	if not _well_in_range(peer_id, player, data, point) or not claims.take_claim(peer_id, data):
		claims.reject(peer_id, &"well_out_of_bounds")
		return
	var well: GravityWell = GravityWell.open(session, player, point, data, false, claims)
	if well == null:
		claims.reject(peer_id, &"well_out_of_bounds")
		return
	if Net.is_coop(multiplayer):
		show_well.rpc(peer_id, point)


@rpc("authority", "call_remote", "reliable")
func show_well(peer_id: int, point: Vector3) -> void:
	var player: Player = session.players.find_player(peer_id)
	if player:
		GravityWell.open(session, player, point, null, true)


func send_well_orb(origin: Vector3, direction: Vector3, weapon_id: StringName) -> void:
	if multiplayer.is_server():
		_remember_well_launch(multiplayer.get_unique_id(), origin)
		if Net.is_coop(multiplayer):
			_relay_well_orb(multiplayer.get_unique_id(), origin, direction)
	elif Net.is_coop(multiplayer):
		well_orb.rpc_id(1, origin, direction, weapon_id)


@rpc("any_peer", "call_remote", "reliable")
func well_orb(origin: Vector3, direction: Vector3, weapon_id: StringName) -> void:
	if not multiplayer.is_server() or not origin.is_finite() or not direction.is_finite():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Player = session.players.find_player(sender)
	var data: WeaponData = _well_weapon(weapon_id)
	if data == null:
		session.hit_claims.reject(sender, &"well_wrong_weapon")
		return
	if player == null or not player.is_alive() or direction.is_zero_approx():
		return
	if player.camera.global_position.distance_to(origin) > 2.0 or not _take_orb_claim(sender, data):
		return
	_remember_well_launch(sender, origin)
	_relay_well_orb(sender, origin, direction)


func _remember_well_launch(peer_id: int, origin: Vector3) -> void:
	var launches: Array = _well_launches.get(peer_id, [])
	while not launches.is_empty() and float(launches[0].time) < _time - FLIGHT_TIME:
		launches.pop_front()
	launches.append({"origin": origin, "time": _time})
	_well_launches[peer_id] = launches


func _well_in_range(peer_id: int, player: Player, data: WeaponData, point: Vector3) -> bool:
	if player.camera.global_position.distance_to(point) <= data.max_range + 2.0:
		return true
	for launch: Dictionary in _well_launches.get(peer_id, []):
		if _time - float(launch.time) <= FLIGHT_TIME:
			var origin: Vector3 = launch.origin
			if origin.distance_to(point) <= data.max_range + 2.0:
				return true
	return false


func _relay_well_orb(peer_id: int, origin: Vector3, direction: Vector3) -> void:
	if peer_id != multiplayer.get_unique_id():
		show_well_orb(peer_id, origin, direction)
	for recipient: int in multiplayer.get_peers():
		if recipient != peer_id:
			show_well_orb.rpc_id(recipient, peer_id, origin, direction)


@rpc("authority", "call_remote", "unreliable")
func show_well_orb(peer_id: int, origin: Vector3, direction: Vector3) -> void:
	var player: Player = session.players.find_player(peer_id)
	if player:
		GravityWell.spawn_orb(session, player, origin, direction, null, false)


func _take_orb_claim(peer_id: int, data: WeaponData) -> bool:
	var recent: Array = _orb_claims.get(peer_id, [])
	while not recent.is_empty() and float(recent[0]) <= _time - 1.0:
		recent.pop_front()
	_orb_claims[peer_id] = recent
	if recent.size() + 1 > data.rounds_per_minute / 60.0 * HitClaims.SLACK + 2.0:
		return false
	recent.append(_time)
	return true

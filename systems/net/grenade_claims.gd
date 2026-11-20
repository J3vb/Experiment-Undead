## Grenade throws in co-op (docs/MULTIPLAYER.md patterns 2 and 6): the owner asks, the
## server checks and throws the real grenade, everyone else sees a cosmetic copy and the blast.
class_name GrenadeClaims
extends Node

## Emitted on every peer that shows a blast (the effect in step 3 listens).
signal blast_shown(peer_id: int, position: Vector3)

## The throw leaves within this distance of the thrower's eyes.
const ORIGIN_SLACK: float = 2.0
## Player movement the throw speed may add on top of the frag's own speed.
const SPEED_SLACK: float = 10.0

var session: GameSession

var _time: float = 0.0
var _last_throw: Dictionary[int, float] = {}


func _init() -> void:
	name = "GrenadeClaims"


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_forget_peer)


func _physics_process(delta: float) -> void:
	_time += delta


func _forget_peer(peer_id: int) -> void:
	_last_throw.erase(peer_id)


## Owner: throw. The server runs it directly; a client shows its own copy at once and asks.
func request_throw(player: Player, origin: Vector3, velocity: Vector3, fuse: float) -> void:
	if multiplayer.is_server():
		_accept(multiplayer.get_unique_id(), origin, velocity, fuse)
		return
	_spawn_copy(player, origin, velocity, fuse)
	throw_on_server.rpc_id(1, origin, velocity, fuse)


@rpc("any_peer", "call_remote", "reliable")
func throw_on_server(origin: Vector3, velocity: Vector3, fuse: float) -> void:
	if multiplayer.is_server():
		_accept(multiplayer.get_remote_sender_id(), origin, velocity, fuse)


## Empty when the throw is fine, else the reason to refuse it.
func check(player: Player, origin: Vector3, velocity: Vector3, fuse: float) -> StringName:
	if player == null or not player.is_alive() or player.is_downed:
		return &"grenade_not_alive"
	var thrower: GrenadeThrower = player.grenades
	if thrower.count <= 0:
		return &"grenade_none_left"
	if not _fair_throw(player, thrower.data, origin, velocity, fuse):
		return &"grenade_bad_throw"
	if _last_throw.has(player.net_id) and _time - _last_throw[player.net_id] < thrower.data.recover_time * 0.5:
		return &"grenade_too_fast"
	return &""


## Leaves from the thrower's eyes, no faster than a throw can be, with no more fuse than the frag has.
func _fair_throw(player: Player, data: ThrowableData, origin: Vector3, velocity: Vector3, fuse: float) -> bool:
	if not origin.is_finite() or not velocity.is_finite() or is_nan(fuse):
		return false
	var near: bool = player.camera.global_position.distance_to(origin) <= ORIGIN_SLACK
	return near and velocity.length() <= data.throw_speed + SPEED_SLACK and fuse >= 0.0 and fuse <= data.fuse


func _accept(peer_id: int, origin: Vector3, velocity: Vector3, fuse: float) -> void:
	var player: Player = session.players.find_player(peer_id) if session.players else null
	var reason: StringName = check(player, origin, velocity, fuse)
	if reason != &"":
		session.hit_claims.reject(peer_id, reason)
		return
	_last_throw[peer_id] = _time
	var thrower: GrenadeThrower = player.grenades
	thrower.count -= 1
	if player.state_sync:
		player.state_sync.queue_publish()
	var grenade: Grenade = Grenade.spawn(session, thrower.data, player, origin, velocity, fuse)
	grenade.claims = self
	for recipient: int in multiplayer.get_peers():
		if recipient != peer_id:
			show_throw.rpc_id(recipient, peer_id, origin, velocity, fuse)


@rpc("authority", "call_remote", "unreliable")
func show_throw(peer_id: int, origin: Vector3, velocity: Vector3, fuse: float) -> void:
	var player: Player = session.players.find_player(peer_id) if session.players else null
	if player:
		_spawn_copy(player, origin, velocity, fuse)


func _spawn_copy(player: Player, origin: Vector3, velocity: Vector3, fuse: float) -> Grenade:
	var thrower: GrenadeThrower = player.grenades
	var copy: Grenade = Grenade.spawn(session, thrower.data, player, origin, velocity, fuse)
	copy.gameplay = false
	return copy


## Server: the real grenade went off; everyone sees it where the server says.
func broadcast_blast(peer_id: int, position: Vector3) -> void:
	if not multiplayer.is_server():
		return
	blast_shown.emit(peer_id, position)
	if Net.is_coop(multiplayer):
		show_blast.rpc(peer_id, position)


@rpc("authority", "call_remote", "reliable")
func show_blast(peer_id: int, position: Vector3) -> void:
	blast_shown.emit(peer_id, position)

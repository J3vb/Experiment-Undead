## Trusted owners claim their local hits; the server checks bounds and applies
## normal HitZone damage. Client kill markers wait for the synced death.
class_name HitClaims
extends Node

const KILL_WINDOW: float = 0.5
const SLACK: float = 1.5

var session: GameSession

var _time: float = 0.0
var _next_warning: float = 0.0
var _claims: Dictionary[int, Dictionary] = {}
var _recent_hits: Array[Dictionary] = []
var _weapons: Dictionary[StringName, WeaponData] = {}


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_forget_peer)
	for id: StringName in Content.ids(&"weapons"):
		_weapons[id] = Content.weapon(id)


func _physics_process(delta: float) -> void:
	_time += delta
	var index: int = _recent_hits.size() - 1
	while index >= 0:
		var hit: Dictionary = _recent_hits[index]
		if not is_instance_valid(hit.zombie) or _time - float(hit.time) > KILL_WINDOW:
			_recent_hits.remove_at(index)
		elif (hit.zombie as Zombie).state == Zombie.State.DEAD:
			if is_instance_valid(hit.player):
				Events.hit_confirmed.emit(hit.player as Player, true, hit.headshot)
			_recent_hits.remove_at(index)
		index -= 1


## Called by the owning gun instead of mutating the client's health copy.
func submit_hit(weapon: Weapon, hit_zone: HitZone, info: DamageInfo) -> void:
	if multiplayer.is_server() or weapon.shooter == null or not weapon.shooter.is_multiplayer_authority():
		return
	var zombie: Zombie = hit_zone.health.get_parent() as Zombie if hit_zone.health else null
	if zombie == null or zombie.get_parent() != session.spawner or zombie.state == Zombie.State.DEAD:
		return
	info.hit_zone = hit_zone.zone
	weapon.hit_landed.emit(false, info.is_headshot())
	_remember_hit(zombie, weapon.shooter, info.is_headshot())
	claim_hit.rpc_id(1, zombie.name, hit_zone.zone, info.amount, info.weapon_id, info.position)


func _remember_hit(zombie: Zombie, player: Player, headshot: bool) -> void:
	for hit: Dictionary in _recent_hits:
		if is_instance_valid(hit.zombie) and hit.zombie == zombie:
			hit.time = _time
			hit.player = player
			hit.headshot = headshot
			return
	_recent_hits.append({"zombie": zombie, "time": _time, "player": player, "headshot": headshot})


@rpc("any_peer", "call_remote", "reliable")
func claim_hit(zombie_name: StringName, zone: int, amount: float, weapon_id: StringName, point: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Player = session.players.find_player(sender)
	if (
		player == null
		or player.is_dead
		or not (player.is_alive() or player.is_downed)
		or session.is_over
		or (player.is_downed and weapon_id != PlayerStateSync.PISTOL)
	):
		_reject(sender, &"player_not_alive")
		return
	var zombie: Zombie = session.spawner.get_node_or_null(NodePath(String(zombie_name))) as Zombie
	if (
		zombie == null
		or zombie.get_parent() != session.spawner
		or zombie.health.is_dead
		or zombie.state == Zombie.State.DEAD
	):
		_reject(sender, &"zombie_not_alive")
		return
	var weapon: WeaponData = _weapons.get(weapon_id)
	if not _valid_hit(player, weapon, amount, point):
		_reject(sender, &"hit_out_of_bounds")
		return
	var hit_zone: HitZone = _find_zone(zombie, zone)
	if hit_zone == null:
		_reject(sender, &"zone_missing")
		return
	if not _take_claim(sender, weapon):
		_reject(sender, &"claims_too_fast")
		return
	var info: DamageInfo = DamageInfo.create(amount, player)
	info.weapon_id = weapon_id
	info.position = point
	info.impulse = (point - player.camera.global_position).normalized() * 2.0
	hit_zone.receive_hit(info)


func _valid_hit(player: Player, weapon: WeaponData, amount: float, point: Vector3) -> bool:
	if weapon == null or not is_finite(amount) or amount <= 0.0 or not point.is_finite():
		return false
	if player.camera.global_position.distance_to(point) > weapon.max_range + 2.0:
		return false
	var maximum: float = maxf(weapon.damage, weapon.min_damage) * weapon.head_multiplier
	maximum *= player.get_stat(&"head_damage") * SLACK
	return amount <= maximum


func _find_zone(zombie: Zombie, zone: int) -> HitZone:
	for hit_zone: HitZone in zombie.hit_zones:
		if hit_zone.zone == zone:
			return hit_zone
	return null


func _take_claim(sender: int, weapon: WeaponData) -> bool:
	if not _claims.has(sender):
		_claims[sender] = {}
	var per_weapon: Dictionary = _claims[sender]
	var recent: Array = per_weapon.get(weapon.id, [])
	while not recent.is_empty() and float(recent[0]) <= _time - 1.0:
		recent.pop_front()
	var hits_per_shot: int = weapon.pellets * (maxi(weapon.pierce_count, 0) + 1)
	var limit: float = weapon.rounds_per_minute / 60.0 * hits_per_shot * SLACK + 2.0
	per_weapon[weapon.id] = recent
	if recent.size() + 1 > limit:
		return false
	recent.append(_time)
	return true


func _reject(sender: int, reason: StringName) -> void:
	if _time < _next_warning:
		return
	_next_warning = _time + 1.0
	Log.warn(&"net", &"hit_claim_rejected", {"peer": sender, "reason": reason})


func _forget_peer(peer_id: int) -> void:
	_claims.erase(peer_id)

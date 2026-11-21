## Trusted owners claim their local hits; the server checks bounds and applies
## normal HitZone damage. Client kill markers wait for the synced death.
class_name HitClaims
extends Node

const KILL_WINDOW: float = 0.5
const SLACK: float = 1.5
const MAX_IMPULSE: float = 12.0
## Execution Line kills a zombie hit while under this share of its health.
const EXECUTE_BELOW: float = 0.15

var session: GameSession

var _time: float = 0.0
var _next_warning: float = 0.0
var _claims: Dictionary[int, Dictionary] = {}
var _recent_hits: Array[Dictionary] = []
var _weapons: Dictionary[StringName, WeaponData] = {}
var _chain: Chain = Chain.new()
## Per peer: [player stats, Content gun, that gun fitted with the stats]. Pellet claims reuse it.
var _fitted: Dictionary[int, Array] = {}


func _ready() -> void:
	add_child(_chain)
	multiplayer.peer_disconnected.connect(_forget_peer)
	for type: StringName in [&"weapons", &"melee"]:
		for id: StringName in Content.ids(type):
			_weapons[id] = Content.get_item(type, id) as WeaponData


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
	if claim_local(weapon.shooter, hit_zone, info):
		weapon.hit_landed.emit(false, info, hit_zone)


## Sends the local owner's hit to the host. True when a claim went out (show the hit marker).
func claim_local(shooter: Player, hit_zone: HitZone, info: DamageInfo) -> bool:
	if multiplayer.is_server() or shooter == null or not shooter.is_multiplayer_authority():
		return false
	var zombie: Zombie = hit_zone.health.get_parent() as Zombie if hit_zone.health else null
	if zombie == null or zombie.get_parent() != session.spawner or zombie.state == Zombie.State.DEAD:
		return false
	info.hit_zone = hit_zone.zone
	_remember_hit(zombie, shooter, info.is_headshot())
	claim_hit.rpc_id(
		1, zombie.name, hit_zone.zone, info.amount, info.weapon_id, info.position, info.impulse, info.item_uid
	)
	return true


func _remember_hit(zombie: Zombie, player: Player, headshot: bool) -> void:
	for hit: Dictionary in _recent_hits:
		if is_instance_valid(hit.zombie) and hit.zombie == zombie:
			hit.time = _time
			hit.player = player
			hit.headshot = headshot
			return
	_recent_hits.append({"zombie": zombie, "time": _time, "player": player, "headshot": headshot})


## The arguments are the claim's wire format, so they stay flat instead of a packed Dictionary.
@rpc("any_peer", "call_remote", "reliable")
# gdlint:ignore = function-arguments-number
func claim_hit(
	zombie_name: StringName,
	zone: int,
	amount: float,
	weapon_id: StringName,
	point: Vector3,
	impulse: Vector3 = Vector3.ZERO,
	item_uid: String = ""
) -> void:
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
		reject(sender, &"player_not_alive")
		return
	var zombie: Zombie = session.spawner.get_node_or_null(NodePath(String(zombie_name))) as Zombie
	if (
		zombie == null
		or zombie.get_parent() != session.spawner
		or zombie.health.is_dead
		or zombie.state == Zombie.State.DEAD
	):
		reject(sender, &"zombie_not_alive")
		return
	var item: ItemInstance = player.item_guns.get(item_uid) if not item_uid.is_empty() else null
	var weapon: WeaponData = _weapons.get(weapon_id)
	if item and weapon:
		weapon = _trait_bounds(item.weapon_data(weapon, player.stats), item)
	elif weapon and weapon.slot != WeaponData.Slot.MELEE:
		weapon = _fitted_gun(sender, player, weapon)
	if not _valid_hit(player, weapon, amount, point, impulse):
		reject(sender, &"hit_out_of_bounds")
		return
	var hit_zone: HitZone = _find_zone(zombie, zone)
	if hit_zone == null:
		reject(sender, &"zone_missing")
		return
	if not take_claim(sender, weapon):
		reject(sender, &"claims_too_fast")
		return
	var info: DamageInfo = DamageInfo.create(amount, player)
	info.weapon_id = weapon_id
	info.item_uid = item_uid if item else ""
	info.position = point
	info.impulse = impulse if impulse != Vector3.ZERO else (point - player.camera.global_position).normalized() * 2.0
	apply_server_hit(hit_zone, info)


## Standalone weapon tests retain the direct path without a live session.
static func apply_host_hit(shooter: Player, hit_zone: HitZone, info: DamageInfo) -> void:
	if shooter and shooter.session and shooter.session.hit_claims:
		shooter.session.hit_claims.apply_server_hit(hit_zone, info)
	else:
		hit_zone.receive_hit(info)


## Shared effect hook for validated claims and the host's direct hits.
func apply_server_hit(hit_zone: HitZone, info: DamageInfo) -> void:
	if not multiplayer.is_server():
		return
	var zombie: Zombie = hit_zone.health.get_parent() as Zombie if hit_zone.health else null
	if zombie == null:
		hit_zone.receive_hit(info)
		return
	if zombie.health.is_dead or zombie.state == Zombie.State.DEAD:
		return
	info.hit_zone = hit_zone.zone
	var weapon: WeaponData = _weapons.get(info.weapon_id)
	info.damage_type = DamageInfo.Type.MELEE if weapon and weapon.slot == WeaponData.Slot.MELEE else info.damage_type
	var effect: WeaponData.Effect = weapon.effect if weapon else WeaponData.Effect.NONE
	var collateral_killed: bool = false
	if effect == WeaponData.Effect.CHAIN:
		collateral_killed = _chain.apply(zombie, info)
	if (zombie.frozen or effect == WeaponData.Effect.FROST) and not zombie.stasis:
		if Frost.apply(zombie, info):
			return
	var overkill: bool = session.power_up_drops and session.power_up_drops.is_active(PowerUpData.Effect.OVERKILL)
	if overkill or _executes(zombie, info):
		info.amount = maxf(info.amount, zombie.health.current / maxf(hit_zone.damage_multiplier, 0.01) + 1.0)
	if session and session.legendary_traits:
		session.legendary_traits.on_hit(zombie, info)
	hit_zone.receive_hit(info)
	_confirm_secondary_kill(zombie, info, collateral_killed)


## Execution Line: any hit on a zombie already under EXECUTE_BELOW of its health kills it.
func _executes(zombie: Zombie, info: DamageInfo) -> bool:
	var player: Player = info.attacker as Player
	if player == null or not player.skill_rules.has(SkillNodeData.Rule.EXECUTION_LINE):
		return false
	return zombie.health.get_ratio() < EXECUTE_BELOW


## Defer past the normal hit marker; primary kills already confirm themselves.
func _confirm_secondary_kill(zombie: Zombie, info: DamageInfo, killed: bool) -> void:
	if killed and not zombie.health.is_dead and info.attacker is Player:
		confirm_area_hit.call_deferred(info.attacker as Player, true)


func _valid_hit(player: Player, weapon: WeaponData, amount: float, point: Vector3, impulse: Vector3) -> bool:
	if weapon == null or not is_finite(amount) or amount <= 0.0 or not point.is_finite():
		return false
	if not impulse.is_finite() or impulse.length_squared() > MAX_IMPULSE * MAX_IMPULSE:
		return false
	if player.camera.global_position.distance_to(point) > weapon.max_range + 2.0:
		return false
	var maximum: float = maxf(weapon.damage, weapon.min_damage) * weapon.head_multiplier
	maximum *= player.get_stat(&"head_damage") * SLACK
	return amount <= maximum


## An owner trait gun's bounds: Dead Man's Hand's last round hits harder, Overpressure fires more pellets.
static func _trait_bounds(weapon: WeaponData, item: ItemInstance) -> WeaponData:
	var last_round: float = item.stats.value(&"dead_mans_hand", 0.0)
	if last_round > 1.0:
		weapon.damage *= last_round
		weapon.min_damage *= last_round
	var pellets: float = item.stats.value(&"overpressure", 0.0)
	if pellets > 1.0:
		weapon.pellets = roundi(weapon.pellets * pellets)
	return weapon


## The Content gun with the sender's gear and skill lines, rebuilt only when their stats object changes.
func _fitted_gun(sender: int, player: Player, weapon: WeaponData) -> WeaponData:
	var cached: Array = _fitted.get(sender, [])
	if cached.size() == 3 and cached[0] == player.stats and cached[1] == weapon:
		return cached[2]
	var fitted: WeaponData = ItemInstance.fit_player_gun(weapon, player.stats)
	_fitted[sender] = [player.stats, weapon, fitted]
	return fitted


## The server's cached copy of a gun or melee weapon, or null for an unknown id.
func cached_weapon(id: StringName) -> WeaponData:
	return _weapons.get(id)


func _find_zone(zombie: Zombie, zone: int) -> HitZone:
	for hit_zone: HitZone in zombie.hit_zones:
		if hit_zone.zone == zone:
			return hit_zone
	return null


## Per-gun claim window shared with WellClaims: false once a sender claims faster than the gun fires.
func take_claim(sender: int, weapon: WeaponData) -> bool:
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


## Logs a refused claim, at most once a second.
func reject(sender: int, reason: StringName) -> void:
	if _time < _next_warning:
		return
	_next_warning = _time + 1.0
	Log.warn(&"net", &"hit_claim_rejected", {"peer": sender, "reason": reason})


func _forget_peer(peer_id: int) -> void:
	_claims.erase(peer_id)
	_fitted.erase(peer_id)


func confirm_area_hit(player: Player, killed: bool) -> void:
	if not multiplayer.is_server() or not is_instance_valid(player):
		return
	Events.hit_confirmed.emit(player, killed, false)
	if player.net_id != multiplayer.get_unique_id() and multiplayer.get_peers().has(player.net_id):
		area_hit.rpc_id(player.net_id, killed)


@rpc("authority", "call_remote", "reliable")
func area_hit(killed: bool) -> void:
	var player: Player = session.players.find_player(multiplayer.get_unique_id())
	if player:
		Events.hit_confirmed.emit(player, killed, false)

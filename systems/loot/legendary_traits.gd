## Legendary trait effects that run where the server applies hits, and the per-player state they need.
## Lives on every peer (later RPCs need the same path); state and effects run on the server only.
## Bonus hits (Lantern Fall, Ricochet) carry no item uid: no points, no Leech, no further traits.
class_name LegendaryTraits
extends Node

## Trait stats with code. tests/content/test_legendaries.gd fails on a Legendary naming any other.
const STATS: Array[StringName] = [
	&"tidewater",
	&"lantern_fall",
	&"ricochet",
	&"choir_mark",
	&"bloodline",
	&"black_ledger",
	&"bottomless",
	&"overpressure",
	&"dead_mans_hand",
	&"cold_snap",
]
const TIDEWATER_MAX_STACKS: int = 10
## Provisional: affixes.md gives no radius (the middle of the other trait radii).
const LANTERN_FALL_RADIUS: float = 4.0
const RICOCHET_RANGE: float = 8.0
const CHOIR_MARK_RANGE: float = 6.0
const CHOIR_MARK_SECONDS: float = 4.0
const BLACK_LEDGER_POINTS: int = 10000
const COLD_SNAP_SECONDS: float = 2.0
## Cold Snap may come again after this share of the gun's empty reload time (reload speed bonuses).
const SLACK_FRACTION: float = 0.5

var session: GameSession

var _time: float = 0.0
## Per attacker net id: [zombie instance id, stacks].
var _tidewater: Dictionary[int, Array] = {}
## Per marked zombie instance id: [expires at, bonus percent].
var _marks: Dictionary[int, Array] = {}
## Per peer: when its next Cold Snap is allowed.
var _cold_snap_ready: Dictionary[int, float] = {}
var _next_warning: float = 0.0


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_forget_peer)
	Events.enemy_killed.connect(_on_enemy_killed)


func _physics_process(delta: float) -> void:
	_time += delta


## Server: scales one validated hit by its traits before it lands; a headshot may ricochet.
func on_hit(zombie: Zombie, info: DamageInfo) -> void:
	var player: Player = info.attacker as Player
	if not multiplayer.is_server() or player == null:
		return
	info.amount *= _mark_scale(zombie)
	if player.stats.value(&"black_ledger", 0.0) > 0.0 and player.wallet.points > BLACK_LEDGER_POINTS:
		info.amount *= 1.0 + player.stats.value(&"black_ledger", 0.0) / 100.0
	var item: ItemInstance = player.item_guns.get(info.item_uid) if not info.item_uid.is_empty() else null
	if item == null:
		return
	var tidewater: float = item.stats.value(&"tidewater", 0.0)
	if tidewater > 0.0:
		info.amount *= 1.0 + _tidewater_stacks(player.net_id, zombie) * tidewater / 100.0
	var ricochet: float = item.stats.value(&"ricochet", 0.0)
	if ricochet > 0.0 and info.is_headshot():
		_ricochet(zombie, info, ricochet)


## Server: an item gun's Bloodline for one applied hit (called beside Leech).
static func bloodline(player: Player, item: ItemInstance, info: DamageInfo) -> void:
	var share: float = item.stats.value(&"bloodline", 0.0)
	if share > 0.0 and player.health.current < player.health.max_health * 0.5:
		player.health.heal(info.amount * share / 100.0)


func _on_enemy_killed(enemy: Node3D, info: DamageInfo) -> void:
	_marks.erase(enemy.get_instance_id())
	var player: Player = info.attacker as Player
	if not multiplayer.is_server() or player == null or info.item_uid.is_empty():
		return
	var item: ItemInstance = player.item_guns.get(info.item_uid)
	if item == null or not enemy is Zombie:
		return
	var mark: float = item.stats.value(&"choir_mark", 0.0)
	if mark > 0.0:
		for zombie: Zombie in _near(enemy as Zombie, CHOIR_MARK_RANGE):
			_marks[zombie.get_instance_id()] = [_time + CHOIR_MARK_SECONDS, mark]
	var blast: float = item.stats.value(&"lantern_fall", 0.0)
	if blast > 0.0 and info.is_headshot():
		_lantern_fall(enemy as Zombie, player, item, blast)


## Owner: Cold Snap after an empty-magazine reload starts. Runs here on the server, else asks it.
func request_cold_snap(player: Player, uid: String) -> void:
	if multiplayer.is_server():
		_cold_snap(player, uid)
	else:
		_request_cold_snap_on_server.rpc_id(1, uid)


@rpc("any_peer", "call_remote", "reliable")
func _request_cold_snap_on_server(uid: String) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Player = session.players.find_player(sender) if session and session.players else null
	var reason: StringName = _cold_snap_problem(player, uid)
	if reason != &"":
		_reject(sender, reason)
		return
	_cold_snap(player, uid)


func _cold_snap_problem(player: Player, uid: String) -> StringName:
	if player == null or not player.is_alive():
		return &"player_not_alive"
	var item: ItemInstance = player.item_guns.get(uid)
	if item == null or item.stats.value(&"cold_snap", 0.0) <= 0.0:
		return &"no_cold_snap"
	if _time < _cold_snap_ready.get(player.net_id, 0.0):
		return &"cold_snap_too_fast"
	return &""


## Server: freezes every live zombie within the trait's reach of the player, without shatter.
func _cold_snap(player: Player, uid: String) -> void:
	var item: ItemInstance = player.item_guns.get(uid)
	if item == null or session == null or session.spawner == null:
		return
	var base: WeaponData = Content.weapon(StringName(item.data.get("base", "")))
	_cold_snap_ready[player.net_id] = _time + (base.empty_reload_time if base else 0.0) * SLACK_FRACTION
	var reach: float = item.stats.value(&"cold_snap", 0.0)
	for child: Node in session.spawner.get_children():
		var zombie: Zombie = child as Zombie
		if zombie and not zombie.health.is_dead and zombie.global_position.distance_to(player.global_position) <= reach:
			Frost.hold(zombie, COLD_SNAP_SECONDS)


func _reject(sender: int, reason: StringName) -> void:
	if _time < _next_warning:
		return
	_next_warning = _time + 1.0
	Log.warn(&"net", &"trait_rejected", {"peer": sender, "reason": reason})


func _mark_scale(zombie: Zombie) -> float:
	var mark: Array = _marks.get(zombie.get_instance_id(), [])
	if mark.is_empty():
		return 1.0
	if float(mark[0]) <= _time:
		_marks.erase(zombie.get_instance_id())
		return 1.0
	return 1.0 + float(mark[1]) / 100.0


## Stacks before this hit, then one more for it. A new target keeps half, rounded down.
func _tidewater_stacks(peer_id: int, zombie: Zombie) -> int:
	var state: Array = _tidewater.get(peer_id, [0, 0])
	var stacks: int = int(state[1])
	if int(state[0]) != zombie.get_instance_id():
		stacks /= 2
	_tidewater[peer_id] = [zombie.get_instance_id(), mini(stacks + 1, TIDEWATER_MAX_STACKS)]
	return stacks


func _ricochet(zombie: Zombie, info: DamageInfo, percent: float) -> void:
	var targets: Array[Zombie] = _near(zombie, RICOCHET_RANGE)
	if targets.is_empty():
		return
	var target: Zombie = targets[0]
	target.health.take_damage(_bonus_hit(info.attacker, info.weapon_id, info.amount * percent / 100.0, target))
	var chain: Chain = session.hit_claims.get_node_or_null("Chain") as Chain if session and session.hit_claims else null
	if chain:
		var ends: PackedVector3Array = PackedVector3Array([target.global_position + Vector3.UP])
		if Net.is_coop(multiplayer):
			chain.show_arcs.rpc(zombie.global_position + Vector3.UP, ends)
		else:
			chain.show_arcs(zombie.global_position + Vector3.UP, ends)


func _lantern_fall(source: Zombie, player: Player, item: ItemInstance, percent: float) -> void:
	var base: WeaponData = Content.weapon(StringName(item.data.get("base", "")))
	if base == null:
		return
	var amount: float = item.weapon_data(base, player.stats).damage * percent / 100.0
	for zombie: Zombie in _near(source, LANTERN_FALL_RADIUS):
		zombie.health.take_damage(_bonus_hit(player, base.id, amount, zombie, DamageInfo.Type.EXPLOSIVE))
	var grenades: GrenadeClaims = session.get_node_or_null("GrenadeClaims") as GrenadeClaims if session else null
	if grenades:
		grenades.broadcast_blast(player.net_id, source.global_position + Vector3.UP)


static func _bonus_hit(
	attacker: Node, weapon_id: StringName, amount: float, target: Zombie, type: DamageInfo.Type = DamageInfo.Type.BULLET
) -> DamageInfo:
	var hit: DamageInfo = DamageInfo.create(amount, attacker, type)
	hit.weapon_id = weapon_id
	hit.position = target.global_position + Vector3.UP
	return hit


## Live zombies within range of source, nearest first.
static func _near(source: Zombie, reach: float) -> Array[Zombie]:
	var found: Array[Zombie] = []
	var parent: Node = source.get_parent()
	if parent == null:
		return found
	for child: Node in parent.get_children():
		var zombie: Zombie = child as Zombie
		if zombie == null or zombie == source or zombie.health.is_dead or zombie.state == Zombie.State.DEAD:
			continue
		if source.global_position.distance_squared_to(zombie.global_position) <= reach * reach:
			found.append(zombie)
	found.sort_custom(
		func(a: Zombie, b: Zombie) -> bool:
			return (
				source.global_position.distance_squared_to(a.global_position)
				< source.global_position.distance_squared_to(b.global_position)
			)
	)
	return found


func _forget_peer(peer_id: int) -> void:
	_tidewater.erase(peer_id)
	_cold_snap_ready.erase(peer_id)

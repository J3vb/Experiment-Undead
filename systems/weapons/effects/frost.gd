## Server-owned frost buildup, timed freezing and a shatter burst. The synced
## frozen flag drives the stopped pose and ice coating on every peer.
class_name Frost
extends Node

const HITS_TO_FREEZE: int = 3
const FREEZE_SECONDS: float = 2.0
const SHATTER_RADIUS: float = 3.0
const SHATTER_DAMAGE: float = 0.5

var buildup: int = 0
var remaining: float = 0.0
## Frozen by a hold (Cold Snap): hits land normally and never shatter.
var held: bool = false

var _zombie: Zombie
var _coating: StandardMaterial3D


## Returns true when shattering consumed the primary hit.
static func apply(zombie: Zombie, info: DamageInfo) -> bool:
	if not zombie.multiplayer.is_server() or zombie.health.is_dead or info.amount <= 0.0:
		return false
	var effect: Frost = _effect(zombie)
	if zombie.frozen and effect.held:
		return false
	if zombie.frozen:
		effect._shatter(info)
		return true
	effect.buildup += 1
	if effect.buildup >= HITS_TO_FREEZE:
		effect.buildup = 0
		effect.remaining = FREEZE_SECONDS
		zombie.frozen = true
	return false


## Server: freezes a zombie for seconds without the shatter rule. A Cryo freeze keeps its shatter.
static func hold(zombie: Zombie, seconds: float) -> void:
	if not zombie.multiplayer.is_server() or zombie.health.is_dead:
		return
	var effect: Frost = _effect(zombie)
	if not zombie.frozen:
		effect.held = true
	effect.remaining = maxf(effect.remaining, seconds)
	zombie.frozen = true


static func _effect(zombie: Zombie) -> Frost:
	var effect: Frost = zombie.get_node_or_null("Frost") as Frost
	if effect == null:
		effect = Frost.new()
		effect.name = "Frost"
		effect._zombie = zombie
		zombie.add_child(effect)
	return effect


## Called by the synced flag; clients only change presentation.
static func show_frozen(zombie: Zombie, enabled: bool) -> void:
	var effect: Frost = _effect(zombie)
	if enabled:
		initialize_pose(zombie)
	if effect._coating == null:
		effect._coating = StandardMaterial3D.new()
		effect._coating.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		effect._coating.albedo_color = Color("cdeee8", 0.32)
		effect._coating.roughness = 0.25
	for node: Node in zombie.visual.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = effect._coating if enabled else null


## A late-join copy may receive its state after the frozen flag and _ready.
static func initialize_pose(zombie: Zombie) -> void:
	if zombie.visual.position.y < -1.79:
		zombie.visual.position = Vector3.ZERO
		zombie.visual.follow(zombie, 0.0)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not _zombie.frozen:
		return
	remaining = maxf(remaining - delta, 0.0)
	if is_zero_approx(remaining) or _zombie.health.is_dead:
		_zombie.frozen = false
		held = false


func _shatter(info: DamageInfo) -> void:
	_zombie.frozen = false
	var kill: DamageInfo = _damage(_zombie.health.current, info, _zombie)
	kill.hit_zone = info.hit_zone
	kill.item_uid = info.item_uid
	kill.damage_type = info.damage_type
	_zombie.health.take_damage(kill)
	for node: Node in _zombie.get_parent().get_children():
		var neighbour: Zombie = node as Zombie
		if neighbour == null or neighbour == _zombie or not neighbour.frozen or neighbour.health.is_dead:
			continue
		if _zombie.global_position.distance_squared_to(neighbour.global_position) <= SHATTER_RADIUS * SHATTER_RADIUS:
			neighbour.health.take_damage(_damage(info.amount * SHATTER_DAMAGE, info, neighbour))


func _damage(amount: float, source: DamageInfo, zombie: Zombie) -> DamageInfo:
	var info: DamageInfo = DamageInfo.create(amount, source.attacker)
	info.weapon_id = source.weapon_id
	info.position = zombie.global_position + Vector3.UP
	return info

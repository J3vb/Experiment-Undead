## Everything a damage receiver needs to know about one hit.
class_name DamageInfo
extends RefCounted

enum Type { BULLET, MELEE }
enum Zone { BODY, HEAD, LIMB }

var amount: float = 0.0
var attacker: Node = null
var weapon_id: StringName = &""
## The item gun that fired, or empty. The server pays item on-hit effects for it.
var item_uid: String = ""
var damage_type: Type = Type.BULLET
var hit_zone: Zone = Zone.BODY
var position: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.UP
var impulse: Vector3 = Vector3.ZERO


static func create(p_amount: float, p_attacker: Node, p_type: Type = Type.BULLET) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new()
	info.amount = p_amount
	info.attacker = p_attacker
	info.damage_type = p_type
	return info


func is_headshot() -> bool:
	return hit_zone == Zone.HEAD

## Knife swing: one short ray from the camera against hit zones. A hit takes the
## same path as a gun hit (host applies it, a client claims it) as MELEE damage.
class_name Melee
extends RefCounted

signal hit_landed(is_kill: bool, is_headshot: bool)

const KNIFE: WeaponData = preload("res://content/melee/knife.tres")

var shooter: Player
var camera: Camera3D


## Seconds one swing takes; the gun stays down and cannot fire meanwhile.
static func swing_time() -> float:
	return KNIFE.get_fire_interval()


func swing() -> void:
	if camera == null or not camera.is_inside_tree():
		return
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	var exclude: Array[RID] = []
	if shooter:
		exclude.append(shooter.get_rid())
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + forward * KNIFE.max_range, Layers.WORLD | Layers.HIT_ZONE, exclude
	)
	query.collide_with_areas = true
	var result: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	var hit_zone: HitZone = result.get("collider") as HitZone
	if hit_zone == null:
		return
	var info: DamageInfo = DamageInfo.create(KNIFE.damage, shooter, DamageInfo.Type.MELEE)
	info.weapon_id = KNIFE.id
	info.position = result.position
	info.normal = result.normal
	info.impulse = forward * 2.0
	if not Net.is_authority():
		if shooter and shooter.session and shooter.session.hit_claims.claim_local(shooter, hit_zone, info):
			hit_landed.emit(false, info.is_headshot())
		return
	HitClaims.apply_host_hit(shooter, hit_zone, info)
	hit_landed.emit(hit_zone.health.is_dead, info.is_headshot())

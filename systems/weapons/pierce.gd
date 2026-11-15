## Extends a hitscan through whole zombies; every returned impact uses Weapon's normal hit path.
class_name Pierce
extends RefCounted

const DAMAGE_RETAINED: float = 0.8


static func trace(weapon: Weapon, origin: Vector3, direction: Vector3) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var exclude: Array[RID] = []
	if weapon.shooter:
		exclude.append(weapon.shooter.get_rid())
	var end: Vector3 = origin + direction * weapon.data.max_range
	var start: Vector3 = origin
	var space: PhysicsDirectSpaceState3D = weapon.get_world_3d().direct_space_state
	for index: int in maxi(weapon.data.pierce_count, 0) + 1:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			start, end, Layers.WORLD | Layers.HIT_ZONE, exclude
		)
		query.collide_with_areas = true
		query.hit_from_inside = index > 0
		var result: Dictionary = space.intersect_ray(query)
		if result.is_empty():
			break
		if result.normal == Vector3.ZERO:
			result.normal = -direction
		result["damage_scale"] = pow(DAMAGE_RETAINED, index)
		hits.append(result)
		if not _exclude_zombie(result.collider as HitZone, exclude):
			break
		# RID exclusions pass the zombie without skipping thin world geometry.
		start = result.position
		if (end - start).dot(direction) <= 0.0:
			break
	return hits


static func _exclude_zombie(hit_zone: HitZone, exclude: Array[RID]) -> bool:
	if hit_zone == null or hit_zone.health == null:
		return false
	var zombie: Zombie = hit_zone.health.get_parent() as Zombie
	if zombie == null:
		return false
	for zone: HitZone in zombie.hit_zones:
		if zone.health == hit_zone.health:
			exclude.append(zone.get_rid())
	return true

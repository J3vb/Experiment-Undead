## Server-side power-up effects that reach into other systems, one static function each,
## so PowerUpDrops stays small. Called by PowerUpDrops on the server only.
class_name PowerUpEffects
extends RefCounted


## Stasis on: every zombie alive now stands still. Off: every zombie moves again.
static func set_stasis(spawner: Spawner, on: bool) -> void:
	if spawner == null:
		return
	for zombie: Zombie in spawner.zombies:
		if not on or zombie.state != Zombie.State.DEAD:
			zombie.stasis = on


## Purge: kills every zombie alive now. No attacker, so no kill points, XP, loot or drops;
## the round still counts the kills.
static func purge(spawner: Spawner) -> void:
	if spawner == null:
		return
	for zombie: Zombie in spawner.zombies.duplicate():
		if zombie.state == Zombie.State.DEAD or zombie.health.is_dead:
			continue
		var info: DamageInfo = DamageInfo.create(zombie.health.current + 1.0, null)
		info.position = zombie.global_position + Vector3.UP
		zombie.health.take_damage(info)


## Scrap Kit: every barricade in the level back to full planks.
static func rebuild_barriers(level: Node) -> void:
	for node: Node in level.get_tree().get_nodes_in_group(&"barriers"):
		var barrier: Barrier = node as Barrier
		if barrier and level.is_ancestor_of(barrier):
			barrier.rebuild()

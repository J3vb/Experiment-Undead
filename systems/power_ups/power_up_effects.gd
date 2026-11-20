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

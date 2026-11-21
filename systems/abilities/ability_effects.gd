## Server-side field ability effects, one static function each, switched on AbilityData.Effect
## so FieldAbility stays small. Called by FieldAbility.use() on the server only.
class_name AbilityEffects
extends RefCounted


static func run(data: AbilityData, user: Player, spawner: Spawner) -> void:
	match data.effect:
		AbilityData.Effect.SHOCK_PULSE:
			shock_pulse(spawner, user.global_position, data)


## Every live zombie within radius is pushed away from the centre and stunned for duration.
static func shock_pulse(spawner: Spawner, centre: Vector3, data: AbilityData) -> void:
	if spawner == null:
		return
	var reach: float = data.radius * data.radius
	for zombie: Zombie in spawner.zombies:
		if zombie.state == Zombie.State.DEAD or zombie.global_position.distance_squared_to(centre) > reach:
			continue
		var away: Vector3 = zombie.global_position - centre
		away.y = 0.0
		var push: Vector3 = away.normalized() * data.amount if away.length_squared() > 0.0001 else Vector3.ZERO
		zombie.stun(data.duration, push)

## Server-side field ability effects, one static function each, switched on AbilityData.Effect
## so FieldAbility stays small. Called by FieldAbility.use() on the server only.
class_name AbilityEffects
extends RefCounted


static func run(data: AbilityData, user: Player, spawner: Spawner, at: Vector3) -> void:
	match data.effect:
		AbilityData.Effect.SHOCK_PULSE:
			shock_pulse(spawner, user.global_position, data)
		AbilityData.Effect.MED_BURST:
			med_burst(user, data)
		AbilityData.Effect.ADRENAL_RUSH:
			user.abilities.start_rush(data)
		AbilityData.Effect.DECOY_SIREN:
			decoy_siren(spawner, at, data)
		AbilityData.Effect.WATCHDOG:
			if user.session:
				Watchdog.place(user.session, data, user, at, true)


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


## The user heals to full; living, standing teammates within radius heal by amount. Never revives.
static func med_burst(user: Player, data: AbilityData) -> void:
	user.health.heal(user.health.max_health)
	var reach: float = data.radius * data.radius
	for node: Node in user.get_tree().get_nodes_in_group(&"players"):
		var mate: Player = node as Player
		if mate == null or mate == user or not mate.is_alive() or mate.is_downed:
			continue
		if mate.global_position.distance_squared_to(user.global_position) <= reach:
			mate.health.heal(data.amount)


## Every live zombie within radius of the siren walks to it for duration instead of chasing.
static func decoy_siren(spawner: Spawner, at: Vector3, data: AbilityData) -> void:
	if spawner == null:
		return
	var reach: float = data.radius * data.radius
	for zombie: Zombie in spawner.zombies:
		if zombie.state != Zombie.State.DEAD and zombie.global_position.distance_squared_to(at) <= reach:
			zombie.lure.start(at, data.duration)

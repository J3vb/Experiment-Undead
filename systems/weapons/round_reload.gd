## One-by-one loading shares Weapon's reload state and timer; firing keeps loaded rounds.
## cancel() also stops a normal reload (sprinting cancels reloads, ammo in the magazine stays).
class_name RoundReload
extends RefCounted


static func duration(weapon: Weapon) -> float:
	return maxf(weapon.data.per_round_time * weapon._stat(&"reload_time"), 0.01)


static func can_fire(weapon: Weapon) -> bool:
	return weapon.data.reload_per_round and weapon.state == Weapon.State.RELOADING and weapon.instance.ammo_in_mag > 0


static func cancel(weapon: Weapon) -> void:
	if weapon.state != Weapon.State.RELOADING:
		return
	weapon.state = Weapon.State.IDLE
	weapon._reload_timer = 0.0
	weapon._empty_reload = false
	weapon.pose.mech_audio.stop()


static func tick(weapon: Weapon, delta: float) -> void:
	if not weapon.instance.needs_reload():
		cancel(weapon)
		return
	weapon._reload_timer -= delta
	while weapon._reload_timer <= 0.0 and weapon.state == Weapon.State.RELOADING:
		weapon.instance.ammo_in_mag += 1
		weapon.instance.ammo_reserve -= 1
		weapon._empty_reload = false
		if weapon.instance.needs_reload():
			weapon._reload_timer += weapon._reload_duration
		else:
			cancel(weapon)
		weapon._emit_ammo()

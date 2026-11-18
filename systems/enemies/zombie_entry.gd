## The zombie's way in through its window: queue for an attack slot, tear
## planks or swipe through the gap, then vault over the sill. Part of the
## zombie (it calls the zombie's own steering helpers), kept apart for size.
class_name ZombieEntry
extends RefCounted

## Seconds to climb through an open window (AI doc: 1.0 s vault).
const VAULT_TIME: float = 1.0

## Seconds into the vault, -1 when not vaulting. Synced to clients (ZombieSync).
var vault_time: float = -1.0
var tear_timer: float = 0.0

var _vault_from: Vector3 = Vector3.ZERO


## Take an attack slot at the window (or wait in the queue), tear planks or
## swipe a player through the gap, then vault in once the window is open.
func tick(zombie: Zombie, delta: float) -> void:
	if vault_time >= 0.0:
		_tick_vault(zombie, delta)
		return
	var barrier: Barrier = zombie.barrier
	var slot: int = barrier.claim_slot(zombie)
	var spot: Vector3 = barrier.slot_point(slot) if slot >= 0 else barrier.queue_point(zombie.net_id)
	zombie._update_target(delta)
	var to_spot: Vector3 = spot - zombie.global_position
	to_spot.y = 0.0
	if to_spot.length() > 0.3:
		zombie._steer(to_spot.normalized() * zombie._speed + zombie._separation(), delta)
		zombie._face(to_spot, delta)
		return
	zombie._steer(Vector3.ZERO, delta)
	zombie._face(barrier.global_position - zombie.global_position, delta)
	if slot < 0:
		return
	if barrier.is_broken():
		if barrier.try_start_vault(zombie):
			_vault_from = zombie.global_position
			vault_time = 0.0
		return
	if _can_swipe(zombie):
		zombie._enter(Zombie.State.ATTACKING)
		return
	tear_timer -= delta
	if tear_timer <= 0.0:
		tear_timer = zombie.data.plank_time
		barrier.tear_plank()


## 0..1 while vaulting through a window, -1 otherwise.
func vault_progress() -> float:
	return clampf(vault_time / VAULT_TIME, 0.0, 1.0) if vault_time >= 0.0 else -1.0


func _can_swipe(zombie: Zombie) -> bool:
	var target: Player = zombie.target
	return (
		target != null
		and zombie._attack_cooldown <= 0.0
		and (
			((target.global_position - zombie.global_position) * Vector3(1, 0, 1)).length()
			<= zombie.data.attack_range + Zombie.HIT_SLACK
		)
		and zombie._can_see(target)
	)


## Over the sill on a fixed path; the rig adds the hop (see vault_progress).
func _tick_vault(zombie: Zombie, delta: float) -> void:
	vault_time += delta
	var t: float = clampf(vault_time / VAULT_TIME, 0.0, 1.0)
	var landing: Vector3 = zombie.barrier.inside_point()
	landing.y = _vault_from.y
	zombie.velocity = Vector3.ZERO
	zombie.global_position = _vault_from.lerp(landing, t)
	zombie._face(landing - _vault_from, delta)
	if t >= 1.0:
		zombie.barrier.release(zombie)
		zombie.barrier = null
		zombie.restart_chase()

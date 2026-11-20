## Server power-up effects in solo: Overkill makes every hit kill for 30 s, Stasis stops
## zombies alive at pickup for 8 s, and neither mixes badly with Cryo or Synapse hits.
## Purge kills every zombie with no kill credit; Scrap Kit rebuilds every barricade.
extends GutTest

const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const WAVES: WaveRules = preload("res://content/waves/default_waves.tres")
const CRYO: WeaponData = preload("res://content/weapons/cryo_lance.tres")
const SYNAPSE: WeaponData = preload("res://content/weapons/synapse.tres")
const RIFLE: WeaponData = preload("res://content/weapons/rifle_ar.tres")
const OVERKILL: PowerUpData = preload("res://content/power_ups/overkill.tres")
const STASIS: PowerUpData = preload("res://content/power_ups/stasis.tres")
const PURGE: PowerUpData = preload("res://content/power_ups/purge.tres")
const SCRAP_KIT: PowerUpData = preload("res://content/power_ups/scrap_kit.tres")
const BARRIER: PackedScene = preload("res://systems/interactables/barrier.tscn")

var session: GameSession
var drops: PowerUpDrops
var player: Player


func before_each() -> void:
	session = CoopSide.make(self, "Solo", [&"hit_claims"])
	CoopSide.add_spawn_point(session, Vector3(0, 0, -6))
	drops = session.power_up_drops
	drops.set_physics_process(false)
	player = CoopSide.add_player(session, 1)


func after_each() -> void:
	CoopSide.close(session)


func _zombie(round_number: int = 1, at: Vector3 = Vector3(0, 0, -6)) -> Zombie:
	var zombie: Zombie = session.spawner.spawn(WALKER, round_number, WAVES)
	zombie.set_physics_process(false)
	zombie.position = at
	zombie.state = Zombie.State.CHASING
	return zombie


func _hit(zombie: Zombie, weapon: WeaponData) -> void:
	var info: DamageInfo = DamageInfo.create(weapon.damage, player)
	info.weapon_id = weapon.id
	session.hit_claims.apply_server_hit(zombie.hit_zones[1], info)


func test_overkill_and_stasis_are_timed() -> void:
	assert_eq(OVERKILL.effect, PowerUpData.Effect.OVERKILL)
	assert_eq(OVERKILL.duration, 30.0)
	assert_eq(STASIS.effect, PowerUpData.Effect.STASIS)
	assert_eq(STASIS.duration, 8.0)


func test_overkill_one_body_shot_kills_at_round_20_then_ends() -> void:
	var tough: Zombie = _zombie(20)
	assert_gt(tough.health.current, RIFLE.damage * 10.0, "round 20 health takes many shots")
	drops.start_timer(OVERKILL)
	_hit(tough, RIFLE)
	assert_true(tough.health.is_dead, "one body shot kills")
	drops._physics_process(30.5)
	var next: Zombie = _zombie(20)
	_hit(next, RIFLE)
	assert_false(next.health.is_dead, "normal damage after 30 s")
	assert_almost_eq(next.health.current, next.health.max_health - RIFLE.damage, 0.01)


func test_synapse_chain_under_overkill_does_normal_splash() -> void:
	var target: Zombie = _zombie(20, Vector3(0, 0, -6))
	var neighbour: Zombie = _zombie(20, Vector3(1, 0, -6))
	drops.start_timer(OVERKILL)
	_hit(target, SYNAPSE)
	assert_true(target.health.is_dead)
	assert_almost_eq(
		neighbour.health.current, neighbour.health.max_health - SYNAPSE.damage * Chain.DAMAGE_FRACTION, 0.01
	)


func test_stasis_stops_zombies_alive_at_pickup_for_8_seconds() -> void:
	var zombie: Zombie = _zombie()
	drops.start_timer(STASIS)
	assert_true(zombie.stasis)
	var later: Zombie = _zombie()
	assert_false(later.stasis, "only zombies alive at pickup")
	var at: Vector3 = zombie.global_position
	var clock: float = zombie.state_time
	zombie.velocity = Vector3(4, 0, 0)
	zombie.set_physics_process(true)
	await wait_physics_frames(3)
	assert_eq(zombie.global_position, at, "does not move")
	assert_eq(zombie.state_time, clock, "attack clock and plank tearing stay stopped")
	drops._physics_process(8.5)
	assert_false(zombie.stasis, "moves again after 8 s")
	await wait_physics_frames(2)
	assert_gt(zombie.state_time, clock)


func test_stasis_zombie_cannot_hurt_a_player() -> void:
	var zombie: Zombie = _zombie()
	zombie.target = player
	zombie.state = Zombie.State.ATTACKING
	zombie.state_time = WALKER.attack_windup - 0.01
	drops.start_timer(STASIS)
	var before: float = player.health.current
	zombie.set_physics_process(true)
	await wait_physics_frames(5)
	assert_eq(player.health.current, before)
	assert_eq(zombie.state_time, WALKER.attack_windup - 0.01, "the swing never lands")


func test_cryo_hits_on_a_stasis_zombie_do_not_freeze_or_shatter() -> void:
	var zombie: Zombie = _zombie(20)
	drops.start_timer(STASIS)
	for i: int in Frost.HITS_TO_FREEZE + 1:
		_hit(zombie, CRYO)
	assert_false(zombie.frozen, "no Cryo build-up")
	assert_false(zombie.health.is_dead, "no shatter")
	assert_almost_eq(zombie.health.current, zombie.health.max_health - CRYO.damage * 4.0, 0.01, "normal damage")


func test_a_cryo_freeze_ending_keeps_the_stasis_ice() -> void:
	var zombie: Zombie = _zombie()
	var mesh: MeshInstance3D = zombie.visual.find_children("*", "MeshInstance3D", true, false)[0]
	zombie.frozen = true
	drops.start_timer(STASIS)
	zombie.frozen = false
	assert_not_null(mesh.material_overlay, "still iced while in Stasis")
	drops._physics_process(8.5)
	assert_null(mesh.material_overlay, "ice gone once both end")


func test_power_up_effects_stasis_ignores_dead_zombies() -> void:
	var dead: Zombie = _zombie()
	dead.state = Zombie.State.DEAD
	var alive: Zombie = _zombie()
	PowerUpEffects.set_stasis(session.spawner, true)
	assert_false(dead.stasis)
	assert_true(alive.stasis)
	PowerUpEffects.set_stasis(session.spawner, false)
	assert_false(alive.stasis)


func _collect(data: PowerUpData) -> void:
	drops._spawn(data, Vector3(5, 0, 5)).collect(player)


func test_purge_kills_every_live_zombie_without_kill_credit() -> void:
	var zombies: Array[Zombie] = [_zombie(20), _zombie(20, Vector3(2, 0, -6)), _zombie(20, Vector3(-2, 0, -6))]
	player.wallet.set_points(0)
	watch_signals(Events)
	_collect(PURGE)
	for zombie: Zombie in zombies:
		assert_true(zombie.health.is_dead, "every zombie dies")
	assert_signal_emit_count(Events, "enemy_killed", 3)
	assert_null((get_signal_parameters(Events, "enemy_killed")[1] as DamageInfo).attacker, "nobody gets the kill")
	assert_eq(player.wallet.points, PURGE.team_points, "only the +400, no kill points")
	assert_eq(session.progression.get_xp(player), 0, "no XP")
	assert_eq(PURGE.team_points, 400)


func test_purge_kills_roll_no_power_up_drops() -> void:
	drops.drop_chance = 1.0
	_zombie()
	drops.dropped_this_round = 0
	_collect(PURGE)
	assert_eq(drops.dropped_this_round, 0)


func test_scrap_kit_rebuilds_every_barricade_and_pays_the_team() -> void:
	var broken: Barrier = BARRIER.instantiate() as Barrier
	var half: Barrier = BARRIER.instantiate() as Barrier
	session.level.add_child(broken)
	session.level.add_child(half)
	broken._set_planks(0)
	half._set_planks(3)
	player.wallet.set_points(0)
	_collect(SCRAP_KIT)
	assert_eq(broken.planks, Barrier.PLANKS)
	assert_eq(half.planks, Barrier.PLANKS)
	assert_eq(player.wallet.points, 200)
	assert_eq(SCRAP_KIT.team_points, 200)

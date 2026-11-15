## Real solo hitscan shots reach the shared server effect path for both Prototypes.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const ORIGIN: Vector3 = Vector3(34, 0.8, 55)
const TARGET: Vector3 = Vector3(34, 0, 52)

var session: GameSession
var player: Player


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	session.rng_seed = 77
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	session.director.stop()
	player = session.get_players()[0]
	player.weapons.max_slots = 8
	player.global_position = Vector3(34, 0, 55)
	player.set_physics_process(false)
	for child: Node in session.spawner.get_children():
		if child is Zombie:
			child.free()


func _take(id: StringName) -> Weapon:
	var weapon: Weapon = player.weapons.give(Content.weapon(id))
	weapon.aiming = true
	weapon.ads_progress = 1.0
	return weapon


func _walker(offset: Vector3 = Vector3.ZERO) -> Zombie:
	var zombie: Zombie = session.spawner.spawn(Content.enemy(&"zombie_walker"), 1, session.wave_rules)
	zombie.set_physics_process(false)
	zombie.set_process(false)
	zombie.visual.position.y = 0.0
	zombie.global_position = TARGET + offset
	zombie.rotation = Vector3.ZERO
	zombie.state = Zombie.State.CHASING
	zombie.health.reset(1000.0)
	return zombie


func _freeze(zombie: Zombie) -> void:
	var info: DamageInfo = DamageInfo.create(68.4, player)
	info.weapon_id = &"cryo_lance"
	for index: int in Frost.HITS_TO_FREEZE:
		Frost.apply(zombie, info)


func test_solo_cryo_trace_freezes_then_shatters_only_frozen_neighbours() -> void:
	var weapon: Weapon = _take(&"cryo_lance")
	var source: Zombie = _walker()
	var frozen: Zombie = _walker(Vector3(3, 0, 0))
	var warm: Zombie = _walker(Vector3(1, 0, 0))
	var distant: Zombie = _walker(Vector3(3.01, 0, 0))
	_freeze(frozen)
	_freeze(distant)
	await wait_physics_frames(2)
	for index: int in Frost.HITS_TO_FREEZE:
		weapon._trace(ORIGIN, Vector3.FORWARD)
		assert_eq(source.frozen, index == Frost.HITS_TO_FREEZE - 1, "only the third trace freezes")
	assert_almost_eq(source.health.current, 1000.0 - weapon.data.damage * 3.0, 0.001)
	watch_signals(source.health)
	weapon._trace(ORIGIN, Vector3.FORWARD)
	assert_true(source.health.is_dead, "the fourth trace shatters the frozen target")
	assert_almost_eq(frozen.health.current, 1000.0 - weapon.data.damage * 0.5, 0.001)
	assert_eq(warm.health.current, 1000.0, "the warm neighbour is outside the shatter rule")
	assert_eq(distant.health.current, 1000.0, "frozen neighbours beyond three metres stay untouched")
	if not source.health.is_dead:
		return
	var kill: DamageInfo = get_signal_parameters(source.health, "died")[0] as DamageInfo
	assert_eq(kill.attacker, player, "solo shatter keeps the shooter's normal reward attribution")
	assert_eq(kill.weapon_id, &"cryo_lance")


func test_solo_synapse_trace_hits_three_unique_neighbours_for_half_damage() -> void:
	var weapon: Weapon = _take(&"synapse")
	var source: Zombie = _walker()
	var targets: Array[Zombie] = []
	for index: int in 4:
		targets.append(_walker(Vector3(index + 1.0, 0, 0)))
	await wait_physics_frames(2)
	weapon._trace(ORIGIN, Vector3.FORWARD)
	assert_almost_eq(source.health.current, 1000.0 - weapon.data.damage, 0.001)
	for index: int in targets.size():
		var damage: float = weapon.data.damage * 0.5 if index < 3 else 0.0
		assert_almost_eq(targets[index].health.current, 1000.0 - damage, 0.001)
	assert_eq(session.hit_claims.get_node("Chain").get_child_count(), 3, "the real hit draws three arcs")


func test_solo_synapse_trace_includes_six_metres_and_excludes_beyond() -> void:
	var weapon: Weapon = _take(&"synapse")
	var source: Zombie = _walker()
	var boundary: Zombie = _walker(Vector3(6, 0, 0))
	var outside: Zombie = _walker(Vector3(6.01, 0, 0))
	await wait_physics_frames(2)
	weapon._trace(ORIGIN, Vector3.FORWARD)
	assert_almost_eq(source.health.current, 1000.0 - weapon.data.damage, 0.001)
	assert_almost_eq(boundary.health.current, 1000.0 - weapon.data.damage * 0.5, 0.001)
	assert_eq(outside.health.current, 1000.0)

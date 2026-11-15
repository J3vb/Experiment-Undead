## Frost buildup, stopped simulation, timed thaw and attributed shatter damage.
extends GutTest

const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")

var _arena: Node3D
var _rng: RandomNumberGenerator


func before_each() -> void:
	_arena = Node3D.new()
	add_child_autofree(_arena)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 31


func _zombie(point: Vector3 = Vector3.ZERO) -> Zombie:
	var zombie: Zombie = WALKER.scene.instantiate() as Zombie
	zombie.setup(WALKER, Net.allocate_id(), 100.0, 1.0, 1.0, _rng)
	_arena.add_child(zombie)
	zombie.global_position = point
	zombie.state = Zombie.State.CHASING
	zombie.set_physics_process(false)
	return zombie


func _hit(zombie: Zombie, attacker: Node = null) -> bool:
	var info: DamageInfo = DamageInfo.create(68.4, attacker)
	info.weapon_id = &"cryo_lance"
	return Frost.apply(zombie, info)


func _freeze(zombie: Zombie) -> void:
	for index: int in Frost.HITS_TO_FREEZE:
		_hit(zombie)


func test_frost_builds_then_freezes_for_two_seconds() -> void:
	var zombie: Zombie = _zombie()
	assert_false(_hit(zombie))
	assert_false(zombie.frozen)
	assert_eq((zombie.get_node("Frost") as Frost).buildup, 1)
	_hit(zombie)
	assert_false(zombie.frozen)
	_hit(zombie)
	assert_true(zombie.frozen)
	var frost: Frost = zombie.get_node("Frost") as Frost
	assert_eq(frost.remaining, 2.0)
	frost._physics_process(1.99)
	assert_true(zombie.frozen)
	frost._physics_process(0.01)
	assert_false(zombie.frozen)
	_hit(zombie)
	assert_false(zombie.frozen, "thaw starts a fresh buildup")


func test_frozen_zombie_stops_motion_and_attack_clock() -> void:
	var zombie: Zombie = _zombie()
	_freeze(zombie)
	zombie.state = Zombie.State.ATTACKING
	zombie.state_time = 0.1
	zombie.velocity = Vector3(4.0, -2.0, 1.0)
	var before: Vector3 = zombie.global_position
	zombie._physics_process(0.5)
	assert_eq(zombie.global_position, before)
	assert_eq(zombie.velocity, Vector3.ZERO)
	assert_eq(zombie.state_time, 0.1, "freeze pauses the attack and AI")
	var mesh: MeshInstance3D = zombie.visual.find_children("*", "MeshInstance3D", true, false)[0]
	assert_not_null(mesh.material_overlay, "the synced flag shows an ice coating")
	zombie.frozen = false
	assert_null(mesh.material_overlay)


func test_shatter_kills_and_only_damages_frozen_neighbours_in_range() -> void:
	var source: Zombie = _zombie()
	var frozen: Zombie = _zombie(Vector3(3, 0, 0))
	var warm: Zombie = _zombie(Vector3(1, 0, 0))
	var distant: Zombie = _zombie(Vector3(3.01, 0, 0))
	_freeze(source)
	_freeze(frozen)
	_freeze(distant)
	var attacker: Node = Node.new()
	add_child_autofree(attacker)
	watch_signals(source.health)
	watch_signals(frozen.health)
	assert_true(_hit(source, attacker))
	assert_true(source.health.is_dead)
	assert_false(source.frozen)
	assert_almost_eq(frozen.health.current, frozen.health.max_health - 34.2, 0.001)
	assert_eq(warm.health.current, warm.health.max_health)
	assert_eq(distant.health.current, distant.health.max_health)
	var kill: DamageInfo = get_signal_parameters(source.health, "died")[0]
	var splash: DamageInfo = get_signal_parameters(frozen.health, "damaged")[0]
	assert_eq(kill.attacker, attacker)
	assert_eq(splash.attacker, attacker)
	assert_eq(splash.weapon_id, &"cryo_lance")
	assert_true(frozen.frozen, "splash does not recursively shatter")


func test_dead_zombies_do_not_build_frost() -> void:
	var zombie: Zombie = _zombie()
	zombie.health.is_dead = true
	assert_false(_hit(zombie))
	assert_false(zombie.has_node("Frost"))

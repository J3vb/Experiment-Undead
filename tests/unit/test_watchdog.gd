## Watchdog turret (docs/plans/field-abilities.md, step 6): picks the nearest zombie it can see,
## shoots a head every 0.6 s for 0.4 of max health, credits the user, and leaves after 20 s.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")
const WATCHDOG: AbilityData = preload("res://content/abilities/watchdog.tres")

var root: Node3D
var session: GameSession
var spawner: Spawner
var player: Player


func before_each() -> void:
	session = GameSession.new()
	root = Node3D.new()
	add_child_autofree(root)
	root.add_child(_box(Vector3(100, 1, 100), Vector3(0, -0.5, 0)))
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_watchdog_spawns")
	root.add_child(marker)
	spawner = Spawner.new()
	spawner.session = session
	spawner.spawn_group = &"test_watchdog_spawns"
	root.add_child(spawner)
	session.spawner = spawner
	player = PLAYER.instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	player.local_input.enabled = false
	player.abilities.ability = WATCHDOG


func after_each() -> void:
	session.free()


func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	return body


func _zombie(at: Vector3) -> Zombie:
	var zombie: Zombie = spawner.spawn(WALKER, 1, RULES)
	zombie.set_physics_process(false)
	zombie.global_position = at
	zombie.state = Zombie.State.CHASING
	zombie.visual.position.y = 0.0
	zombie.visual.set_process(false)
	return zombie


func _turret(live: bool = true) -> Watchdog:
	var turret: Watchdog = Watchdog.new()
	turret.data = WATCHDOG
	turret.user = player
	turret.spawner = spawner
	turret.live = live
	root.add_child(turret)
	turret.set_physics_process(false)
	return turret


func test_targets_the_nearest_zombie_it_can_see() -> void:
	var hidden: Zombie = _zombie(Vector3(0, 0, -4))
	var seen: Zombie = _zombie(Vector3(8, 0, 0))
	_zombie(Vector3(-26, 0, 0))
	root.add_child(_box(Vector3(4, 4, 0.5), Vector3(0, 2, -2)))
	var turret: Watchdog = _turret()
	await wait_physics_frames(2)
	assert_eq(turret.find_target(), seen, "the closer one behind a wall is skipped; 26 m is out of range")
	assert_ne(turret.find_target(), hidden)


func test_three_head_shots_kill_and_the_user_gets_the_kill() -> void:
	var zombie: Zombie = _zombie(Vector3(6, 0, 0))
	var turret: Watchdog = _turret()
	await wait_physics_frames(2)
	watch_signals(Events)
	player.abilities.cooldown_left = 60.0
	turret._physics_process(0.2)
	assert_eq(turret.shots, 0, "first shot after 0.6 s")
	turret._physics_process(0.4)
	assert_eq(turret.shots, 1)
	assert_almost_eq(zombie.health.current, zombie.health.max_health * 0.6, 0.01, "0.4 of max health a shot")
	turret._physics_process(0.6)
	turret._physics_process(0.6)
	assert_eq(turret.shots, 3)
	assert_true(zombie.health.is_dead, "three shots kill")
	var killed: Array = get_signal_parameters(Events, "enemy_killed")
	assert_eq((killed[1] as DamageInfo).attacker, player, "the user gets the kill")
	assert_eq(player.abilities.cooldown_left, 59.5, "and the kill credit")


func test_a_client_turret_shoots_without_damage() -> void:
	var zombie: Zombie = _zombie(Vector3(6, 0, 0))
	var turret: Watchdog = _turret(false)
	await wait_physics_frames(2)
	turret._physics_process(0.2)
	turret._physics_process(0.4)
	assert_eq(turret.shots, 1)
	assert_eq(zombie.health.current, zombie.health.max_health)


func test_gone_after_twenty_seconds() -> void:
	var turret: Watchdog = _turret()
	turret._physics_process(19.9)
	assert_false(turret.is_queued_for_deletion())
	turret._physics_process(0.2)
	assert_true(turret.is_queued_for_deletion())


func test_the_ability_sets_it_down_in_front_of_the_user() -> void:
	player.session = session
	player.global_position = Vector3(2, 0, 2)
	assert_true(player.abilities.use())
	var turret: Watchdog = null
	for child: Node in session.get_children():
		if child is Watchdog:
			turret = child
	assert_not_null(turret)
	assert_true(turret.live)
	var ahead: Vector3 = player.global_position - player.global_basis.z * FieldAbility.WATCHDOG_AHEAD
	assert_almost_eq(turret.position.distance_to(ahead), 0.0, 0.01)

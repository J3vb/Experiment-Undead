## Boots a real match and checks the early warnings fire: navmesh timing is
## logged and a zombie that cannot move is reported as stuck.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	var rules: WaveRules = (session.wave_rules.duplicate(true)) as WaveRules
	rules.first_round_delay = 0.2
	rules.spawn_interval_start = 0.2
	rules.min_spawn_distance = 12.0
	session.wave_rules = rules
	session.rng_seed = 99
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 10.0, "navmesh baked")


func after_each() -> void:
	get_tree().paused = false


func test_navmesh_bake_is_logged() -> void:
	var baked: int = Log.event_counts.get("level.navmesh_baked", 0) + Log.event_counts.get("level.navmesh_bake_slow", 0)
	assert_gt(baked, 0)
	assert_gt(Log.event_counts.get("level.navigation_ready", 0), 0)


func test_frozen_zombie_is_reported_stuck() -> void:
	var before: int = Log.event_counts.get("enemies.zombie_stuck", 0)
	await wait_until(func() -> bool: return get_tree().get_node_count_in_group(&"enemies") > 0, 5.0, "a zombie spawned")
	var zombie: Zombie = get_tree().get_first_node_in_group(&"enemies") as Zombie
	zombie.barrier = null
	zombie._speed = 0.0
	var reported: Callable = func() -> bool: return Log.event_counts.get("enemies.zombie_stuck", 0) > before
	await wait_until(reported, ZombieStuckWatch.STUCK_TIME * 2.0 + 2.0, "stuck warning")
	assert_true(reported.call(), "frozen zombie logged as stuck")

## Skills that change play outside the stat read itself: sprint speed, points earned, repair and revive speed.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const BARRIER: PackedScene = preload("res://systems/interactables/barrier.tscn")
const RULES: EconomyRules = preload("res://content/economy/default_economy.tres")

var player: Player


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)


func _rank(ranks: Dictionary[StringName, int]) -> void:
	player.skill_ranks = ranks
	player.equip_gear([])


func _speed_after_one_tick(sprinting: bool) -> float:
	player.velocity = Vector3.ZERO
	player.is_sprinting = sprinting
	player.move_input = Vector2(0.0, -1.0)
	player._move(1.0 / 60.0, InputFrame.new())
	return Vector2(player.velocity.x, player.velocity.z).length()


func test_light_feet_speeds_up_sprint_but_not_walk() -> void:
	var sprint: float = _speed_after_one_tick(true)
	var walk: float = _speed_after_one_tick(false)
	_rank({&"light_feet": 2})
	assert_almost_eq(_speed_after_one_tick(true), sprint * 1.10, 0.0001)
	assert_almost_eq(_speed_after_one_tick(false), walk, 0.0001)


func _economy() -> Economy:
	var economy: Economy = Economy.new()
	economy.rules = RULES
	add_child_autofree(economy)
	return economy


func test_scrounger_pays_its_full_bonus_over_many_small_hits() -> void:
	_rank({&"scrounger": 3})
	var economy: Economy = _economy()
	var before: int = player.wallet.points
	for _hit: int in 10:
		economy._on_enemy_damaged(null, DamageInfo.create(10.0, player))
	assert_eq(player.wallet.points - before, roundi(RULES.points_per_hit * 10 * 1.15))


func test_points_stay_whole_without_scrounger() -> void:
	var economy: Economy = _economy()
	var before: int = player.wallet.points
	economy._on_enemy_damaged(null, DamageInfo.create(10.0, player))
	assert_eq(player.wallet.points - before, RULES.points_per_hit)


func test_repair_cap_still_holds_with_scrounger() -> void:
	_rank({&"scrounger": 3})
	var economy: Economy = _economy()
	var before: int = player.wallet.points
	for _plank: int in 200:
		economy.pay_repair(player)
	assert_eq(player.wallet.points - before, RULES.max_repair_points_per_round)


func test_carpenter_shortens_the_hold_and_the_server_cooldown() -> void:
	var barrier: Barrier = BARRIER.instantiate() as Barrier
	add_child_autofree(barrier)
	var plain: float = barrier.hold_interval(player)
	_rank({&"carpenter": 2})
	assert_almost_eq(barrier.hold_interval(player), plain / 1.6, 0.0001)
	barrier.tear_plank()
	barrier.interact(player)
	assert_almost_eq(barrier._repair_cooldown, Barrier.REPAIR_TIME / 1.6, 0.0001)
	assert_gt(barrier.hold_interval(player), barrier._repair_cooldown, "a held key still clears the cooldown")


func test_undying_and_fast_revive_shorten_the_revive_hold() -> void:
	assert_almost_eq(player.revive.hold_time(), Revive.HOLD_TIME, 0.0001)
	_rank({&"undying": 1})
	assert_almost_eq(player.revive.hold_time(), Revive.HOLD_TIME / 1.5, 0.0001)

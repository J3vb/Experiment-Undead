## Server-side Legendary traits change only the hits of the gun or player that carries them.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")

var traits: LegendaryTraits
var player: Player
var first: Zombie
var second: Zombie
var _session: GameSession
var _spawner: Spawner


func before_each() -> void:
	_session = GameSession.new()
	_session.rng.seed = 11
	_spawner = Spawner.new()
	_spawner.session = _session
	_spawner.spawn_group = &"test_legendary_spawn"
	add_child_autofree(_spawner)
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_legendary_spawn")
	_spawner.add_child(marker)
	traits = LegendaryTraits.new()
	traits.session = _session
	add_child_autofree(traits)
	player = PLAYER.instantiate() as Player
	player.net_id = 1
	add_child_autofree(player)
	player.set_physics_process(false)
	_give("tw", "tidewater")
	player.item_guns["plain"] = ItemInstance.new({"uid": "plain", "base": "rifle_ar", "rar": "rare"})
	first = _zombie(Vector3.ZERO)
	second = _zombie(Vector3(20, 0, 0))


func after_each() -> void:
	_session.free()


func _give(uid: String, legendary: String, q: float = 1.0) -> void:
	var base: String = String((Content.get_item(&"loot", StringName(legendary)) as LegendaryData).base_id)
	player.item_guns[uid] = ItemInstance.new({"uid": uid, "base": base, "rar": "legendary", "trait": [legendary, q]})


func _zombie(point: Vector3) -> Zombie:
	var zombie: Zombie = _spawner.spawn(WALKER, 1, RULES)
	zombie.set_physics_process(false)
	zombie.position = point
	zombie.health.reset(1000.0)
	return zombie


func _info(uid: String, zone: DamageInfo.Zone = DamageInfo.Zone.BODY) -> DamageInfo:
	var info: DamageInfo = DamageInfo.create(100.0, player)
	info.item_uid = uid
	info.hit_zone = zone
	return info


func _hit(zombie: Zombie, uid: String = "tw") -> float:
	var info: DamageInfo = _info(uid)
	traits.on_hit(zombie, info)
	return info.amount


func _kill(zombie: Zombie, uid: String, zone: DamageInfo.Zone) -> void:
	zombie.health.take_damage(_info(uid, zone).scaled(100.0))


func test_tidewater_adds_a_stack_per_hit_up_to_ten() -> void:
	var amounts: Array[float] = []
	for index: int in 12:
		amounts.append(_hit(first))
	for index: int in 4:
		assert_almost_eq(amounts[index], 100.0 + 5.0 * index, 0.001, "hit %d" % index)
	assert_almost_eq(amounts[10], 150.0, 0.001, "ten stacks")
	assert_almost_eq(amounts[11], 150.0, 0.001, "never more than ten")


func test_tidewater_keeps_half_the_stacks_on_a_new_target() -> void:
	for index: int in 11:
		_hit(first)
	assert_almost_eq(_hit(second), 125.0, 0.001, "half of ten")
	assert_almost_eq(_hit(second), 130.0, 0.001)
	assert_almost_eq(_hit(first), 115.0, 0.001, "half of six back on the first")


func test_other_guns_and_hits_without_an_item_are_unchanged() -> void:
	_hit(first)
	assert_eq(_hit(first, "plain"), 100.0)
	assert_eq(_hit(first, ""), 100.0)
	assert_eq(_hit(first, "missing"), 100.0)
	var stranger: DamageInfo = DamageInfo.create(100.0, null)
	stranger.item_uid = "tw"
	traits.on_hit(first, stranger)
	assert_eq(stranger.amount, 100.0)


func test_lantern_fall_headshot_kill_blasts_zombies_within_four_metres() -> void:
	_give("lf", "lantern_fall")
	var near: Zombie = _zombie(Vector3(3, 0, 0))
	var far: Zombie = _zombie(Vector3(6, 0, 0))
	var expected: float = Content.weapon(&"rifle_ar").damage * 0.4
	_kill(first, "lf", DamageInfo.Zone.BODY)
	assert_eq(near.health.current, 1000.0, "a body kill does not explode")
	var target: Zombie = _zombie(Vector3(1, 0, 0))
	_kill(target, "lf", DamageInfo.Zone.HEAD)
	assert_almost_eq(near.health.current, 1000.0 - expected, 0.01, "3 m away is hit")
	assert_eq(far.health.current, 1000.0, "6 m away is not")


func test_lantern_fall_bonus_kills_do_not_explode_again() -> void:
	_give("lf", "lantern_fall")
	var chained: Zombie = _zombie(Vector3(3, 0, 0))
	chained.health.reset(1.0)
	var beyond: Zombie = _zombie(Vector3(6.5, 0, 0))
	_kill(first, "lf", DamageInfo.Zone.HEAD)
	assert_true(chained.health.is_dead)
	assert_eq(beyond.health.current, 1000.0, "the bonus kill carries no item, so no second blast")


func test_ricochet_headshot_hits_the_nearest_zombie_in_eight_metres() -> void:
	_give("rc", "ricochet")
	var near: Zombie = _zombie(Vector3(5, 0, 0))
	var nearer: Zombie = _zombie(Vector3(3, 0, 0))
	var info: DamageInfo = _info("rc", DamageInfo.Zone.HEAD)
	traits.on_hit(first, info)
	assert_almost_eq(nearer.health.current, 930.0, 0.01, "70% of the hit")
	assert_eq(near.health.current, 1000.0)
	traits.on_hit(first, _info("rc"))
	assert_almost_eq(nearer.health.current, 930.0, 0.01, "body shots do not bounce")
	traits.on_hit(second, _info("rc", DamageInfo.Zone.HEAD))
	assert_eq(second.health.current, 1000.0, "nothing within 8 m of the far zombie")


func test_choir_mark_boosts_any_hit_on_marked_zombies_for_four_seconds() -> void:
	_give("cm", "choir_mark")
	var marked: Zombie = _zombie(Vector3(5, 0, 0))
	_kill(first, "cm", DamageInfo.Zone.BODY)
	var other: DamageInfo = DamageInfo.create(100.0, PLAYER.instantiate())
	traits.on_hit(marked, other)
	assert_almost_eq(other.amount, 125.0, 0.001, "another player's hit gets the mark")
	other.attacker.free()
	assert_eq(_hit(second, "plain"), 100.0, "zombies past 6 m are not marked")
	traits._physics_process(4.1)
	assert_eq(_hit(marked, "plain"), 100.0, "marks end after 4 s")


func test_bloodline_heals_only_below_half_health() -> void:
	_give("bl", "bloodline")
	var info: DamageInfo = _info("bl")
	player.health.current = player.health.max_health * 0.6
	LegendaryTraits.bloodline(player, player.item_guns["bl"], info)
	assert_eq(player.health.current, player.health.max_health * 0.6)
	player.health.current = player.health.max_health * 0.4
	LegendaryTraits.bloodline(player, player.item_guns["bl"], info)
	assert_almost_eq(player.health.current, player.health.max_health * 0.4 + 4.0, 0.001, "4% of 100")


func test_black_ledger_needs_more_than_ten_thousand_points() -> void:
	player.stats.add_modifier(&"black_ledger", "flat", 10.0, &"charm")
	player.wallet.points = 10000
	assert_eq(_hit(first, "plain"), 100.0)
	player.wallet.points = 10001
	assert_almost_eq(_hit(first, "plain"), 110.0, 0.001)


func test_cold_snap_holds_zombies_in_reach_without_shatter() -> void:
	_session.spawner = _spawner
	_give("cs", "cold_snap")
	traits.request_cold_snap(player, "cs")
	assert_true(first.frozen, "0 m away")
	assert_false(second.frozen, "20 m away")
	var hit: DamageInfo = DamageInfo.create(10.0, player)
	assert_false(Frost.apply(first, hit), "a held zombie does not shatter")
	assert_true(first.frozen)
	(first.get_node("Frost") as Frost)._physics_process(2.1)
	assert_false(first.frozen, "the hold ends after 2 s")


func test_cold_snap_refuses_a_gun_without_the_trait_and_a_repeat_too_soon() -> void:
	_session.spawner = _spawner
	assert_ne(traits._cold_snap_problem(player, "plain"), &"")
	assert_ne(traits._cold_snap_problem(player, "missing"), &"")
	_give("cs", "cold_snap")
	assert_eq(traits._cold_snap_problem(player, "cs"), &"")
	traits.request_cold_snap(player, "cs")
	assert_eq(traits._cold_snap_problem(player, "cs"), &"cold_snap_too_fast")
	traits._physics_process(1.8)
	assert_eq(traits._cold_snap_problem(player, "cs"), &"")

## Skill ranks change the stats the player reads, stack with gear under the design caps, and a respec removes them.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)


func _rank(ranks: Dictionary[StringName, int]) -> void:
	player.skill_ranks = ranks
	player.equip_gear([])


func test_quick_draw_shortens_aim_time_per_rank() -> void:
	_rank({&"quick_draw": 1})
	assert_almost_eq(player.get_stat(&"ads_time"), 1.0 / 1.05, 0.0001)
	_rank({&"quick_draw": 3})
	assert_almost_eq(player.get_stat(&"ads_time"), 1.0 / 1.15, 0.0001)


func test_weak_spot_raises_headshot_damage() -> void:
	_rank({&"weak_spot": 2})
	assert_almost_eq(player.get_stat(&"head_damage"), 1.10, 0.0001)


func test_fast_hands_shortens_reload_time() -> void:
	_rank({&"fast_hands": 3})
	assert_almost_eq(player.get_stat(&"reload_time"), 1.0 / 1.15, 0.0001)


func test_thick_skin_adds_ten_max_health_per_rank() -> void:
	_rank({&"thick_skin": 3})
	assert_eq(player.health.max_health, 130.0)
	assert_eq(player.health.current, 130.0)


func test_second_breath_starts_regen_sooner() -> void:
	var base: float = player.health.regen_delay
	_rank({&"second_breath": 3})
	assert_almost_eq(player.health.regen_delay, base - 0.9, 0.0001)


func test_lucky_find_adds_loot_luck() -> void:
	_rank({&"lucky_find": 3})
	assert_almost_eq(LootService.player_luck(player, 1), 0.15, 0.0001)


func test_stat_only_for_later_features_still_sits_in_the_stack() -> void:
	_rank({&"gadgeteer": 2, &"sturdy": 1, &"overtime": 2})
	assert_almost_eq(player.stats.value(&"ability_cooldown"), 1.16, 0.0001)
	assert_almost_eq(player.stats.value(&"explosion_guard"), 1.25, 0.0001)
	assert_almost_eq(player.stats.value(&"power_up_duration", 0.0), 6.0, 0.0001)


func test_respec_removes_every_skill_modifier() -> void:
	_rank({&"thick_skin": 3, &"fast_hands": 3, &"undying": 1})
	assert_false(player.skill_rules.is_empty())
	_rank({})
	assert_eq(player.health.max_health, 100.0)
	assert_eq(player.get_stat(&"reload_time"), 1.0)
	assert_true(player.skill_rules.is_empty())
	for modifier: Modifier in player.stats.modifiers:
		assert_ne(modifier.source, SkillEffects.SOURCE)


func test_skills_stack_with_gear_and_stop_at_the_caps() -> void:
	_rank({&"fast_hands": 3, &"thick_skin": 3})
	player.stats.add_modifier(&"reload_pct", "increased", 0.55, &"gear")
	assert_almost_eq(player.get_stat(&"reload_time"), 1.0 / 1.6, 0.0001, "reload stops at +60%")
	player.stats.add_modifier(&"max_health", "flat", 400.0, &"gear")
	assert_eq(player.get_stat(&"max_health", 100.0), 400.0, "max health stops at 400")


func test_serums_stack_on_top_of_the_caps() -> void:
	_rank({&"fast_hands": 3})
	player.stats.add_modifier(&"reload_pct", "increased", 0.55, &"gear")
	var serum: SerumData = SerumData.new()
	serum.multipliers[&"reload_time"] = 0.6
	player.serums.append(serum)
	assert_almost_eq(player.get_stat(&"reload_time"), 0.6 / 1.6, 0.0001)


func test_rule_skills_fill_the_rule_set() -> void:
	_rank({&"last_stand": 1, &"bargain_hunter": 1})
	assert_true(player.skill_rules.has(SkillNodeData.Rule.LAST_STAND))
	assert_true(player.skill_rules.has(SkillNodeData.Rule.BARGAIN_HUNTER))
	assert_false(player.skill_rules.has(SkillNodeData.Rule.UNDYING))


func test_ranks_from_a_save_drop_unknown_ids_and_clamp() -> void:
	var raw: Dictionary = {"thick_skin": 3.0, "fast_hands": 9, "no_such_skill": 2, "quick_draw": 0, "weak_spot": "2"}
	var ranks: Dictionary[StringName, int] = SkillEffects.ranks_from(raw)
	assert_eq(ranks, {&"thick_skin": 3, &"fast_hands": 3} as Dictionary[StringName, int])


func test_ranks_problem_checks_ids_ranks_and_total() -> void:
	assert_eq(SkillEffects.ranks_problem({"thick_skin": 3}), "")
	assert_eq(SkillEffects.ranks_problem({"thick_skin": 4}), "bad_rank")
	assert_eq(SkillEffects.ranks_problem({"thick_skin": 0}), "bad_rank")
	assert_eq(SkillEffects.ranks_problem({"nope": 1}), "unknown_skill")
	assert_eq(SkillEffects.ranks_problem({}), "")

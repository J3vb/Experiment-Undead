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
	assert_eq(player.get_stat(&"max_health", 100.0), 200.0, "flat max health from skills and gear stops at +100")


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


func _wall_rifle() -> Weapon:
	return player.weapons.give(Content.weapon(&"rifle_ar"))


func test_steady_hands_scales_a_wall_gun_recoil() -> void:
	_rank({&"steady_hands": 3})
	var base: RecoilData = Content.weapon(&"rifle_ar").recoil
	var held: RecoilData = _wall_rifle().data.recoil
	assert_almost_eq(held.pattern[0].y, base.pattern[0].y * 0.85, 0.0001)
	assert_almost_eq(held.random_spread, base.random_spread * 0.85, Vector2(0.0001, 0.0001))


func test_deep_pockets_raises_wall_gun_reserve_and_respec_puts_it_back() -> void:
	player.skill_ranks = {&"deep_pockets": 2}
	var rifle: Weapon = _wall_rifle()
	ItemLoadout.apply(player, {})
	assert_eq(rifle.data.max_reserve, 360)
	assert_eq(rifle.instance.ammo_reserve, 180, "spawn refit starts at the raised reserve")
	player.skill_ranks = {}
	ItemLoadout.apply_gear(player, {})
	assert_eq(rifle.data.max_reserve, 300)
	assert_eq(rifle.instance.ammo_reserve, 180, "ammo is kept on a refit while it fits")
	assert_eq(rifle.data.recoil.pattern, Content.weapon(&"rifle_ar").recoil.pattern)


func test_deep_pockets_counts_once_on_an_item_gun() -> void:
	_rank({&"deep_pockets": 2})
	var item: ItemInstance = ItemInstance.new({"v": 1, "uid": "gun", "base": "rifle_ar", "rar": "common", "ilvl": 1})
	var weapon: Weapon = ItemLoadout.equip_weapon(player, item, null)
	assert_eq(weapon.data.max_reserve, 360, "fitted by the item only, not by the holder again")


func test_all_damage_gear_raises_wall_gun_damage_and_taking_it_off_puts_it_back() -> void:
	var vest: Dictionary = {
		"v": 1, "uid": "vest", "base": "vest_medium", "rar": "rare", "ilvl": 30, "aff": [["all_damage", 5, 1.0]]
	}
	var base: WeaponData = Content.weapon(&"rifle_ar")
	var rifle: Weapon = _wall_rifle()
	ItemLoadout.apply(player, {"vest": vest})
	assert_almost_eq(rifle.data.damage, base.damage * 1.06, 0.0001)
	assert_almost_eq(rifle.data.min_damage, base.min_damage * 1.06, 0.0001)
	ItemLoadout.apply_gear(player, {})
	assert_eq(rifle.data.damage, base.damage)


func test_a_player_without_gun_stats_holds_the_shared_content_gun() -> void:
	_rank({&"thick_skin": 3})
	assert_eq(_wall_rifle().data, Content.weapon(&"rifle_ar"))


func test_a_wall_gun_given_while_wearing_mule_and_recoil_gear_is_fitted_and_refits_back() -> void:
	var vest: Dictionary = {
		"v": 1, "uid": "vest", "base": "vest_medium", "aff": [["mule", 5, 1.0], ["recoil_pct", 5, 1.0]]
	}
	ItemLoadout.apply(player, {"vest": vest})
	var base: WeaponData = Content.weapon(&"rifle_ar")
	var rifle: Weapon = _wall_rifle()
	assert_gt(rifle.data.max_reserve, base.max_reserve)
	assert_eq(rifle.instance.ammo_reserve, rifle.data.starting_reserve, "starts with the raised reserve")
	assert_gt(rifle.data.starting_reserve, base.starting_reserve)
	assert_lt(rifle.data.recoil.pattern[0].length(), base.recoil.pattern[0].length(), "smaller kicks")
	ItemLoadout.apply_gear(player, {})
	assert_eq(rifle.data.max_reserve, base.max_reserve)
	assert_eq(rifle.data.recoil.pattern, base.recoil.pattern)

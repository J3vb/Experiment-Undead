## Checks spending, prerequisites, branch gates and immutable rank updates.
extends GutTest


func after_each() -> void:
	Content.reload()


func test_level_one_cannot_spend() -> void:
	var ranks: Dictionary[StringName, int] = {}
	assert_eq(SkillTree.points_available(1, ranks), 0)
	assert_false(SkillTree.can_rank_up(ranks, &"steady_hands", 1))
	assert_eq(SkillTree.rank_up(ranks, &"steady_hands", 1), ranks)


func test_level_two_can_spend_exactly_once() -> void:
	var ranks: Dictionary[StringName, int] = {}
	assert_eq(SkillTree.points_available(2, ranks), 1)
	ranks = SkillTree.rank_up(ranks, &"steady_hands", 2)
	assert_eq(ranks.get(&"steady_hands"), 1)
	assert_eq(SkillTree.points_available(2, ranks), 0)
	assert_false(SkillTree.can_rank_up(ranks, &"steady_hands", 2))
	assert_false(SkillTree.can_rank_up(ranks, &"quick_draw", 2))


func test_max_ranks_is_enforced() -> void:
	var ranks: Dictionary[StringName, int] = {&"steady_hands": 2}
	assert_true(SkillTree.can_rank_up(ranks, &"steady_hands", 50))
	ranks = SkillTree.rank_up(ranks, &"steady_hands", 50)
	assert_eq(ranks[&"steady_hands"], 3)
	assert_false(SkillTree.can_rank_up(ranks, &"steady_hands", 50))
	assert_eq(SkillTree.rank_up(ranks, &"steady_hands", 50), ranks)


func test_every_required_node_needs_at_least_one_rank() -> void:
	Content._by_type[&"skills"][&"test_requires_two"] = "res://tests/fixtures/skills/requires_two.tres"
	var ranks: Dictionary[StringName, int] = {}
	assert_false(SkillTree.can_rank_up(ranks, &"test_requires_two", 50))
	ranks[&"steady_hands"] = 1
	ranks[&"quick_draw"] = 0
	assert_false(SkillTree.can_rank_up(ranks, &"test_requires_two", 50))
	ranks[&"quick_draw"] = 1
	assert_true(SkillTree.can_rank_up(ranks, &"test_requires_two", 50))
	ranks = SkillTree.rank_up(ranks, &"test_requires_two", 50)
	assert_eq(ranks[&"test_requires_two"], 1)


func test_keystone_requires_fifteen_points_in_its_own_branch() -> void:
	# Hand-built ranks exercise gates beyond the named nodes' current capacity.
	var ranks: Dictionary[StringName, int] = {&"steady_hands": 14, &"thick_skin": 5}
	assert_eq(SkillTree.points_in_branch(ranks, &"Marksman"), 14)
	assert_eq(SkillTree.points_in_branch(ranks, &"Survivor"), 5)
	assert_false(SkillTree.can_rank_up(ranks, &"dead_center", 50))
	ranks[&"steady_hands"] = 15
	assert_true(SkillTree.can_rank_up(ranks, &"dead_center", 50))
	assert_eq(SkillTree.rank_up(ranks, &"dead_center", 50).get(&"dead_center"), 1)
	assert_false(SkillTree.can_rank_up(ranks, &"dead_center", 2))


func test_capstone_requires_twenty_five_branch_points() -> void:
	var ranks: Dictionary[StringName, int] = {&"steady_hands": 24}
	assert_false(SkillTree.can_rank_up(ranks, &"execution_line", 50))
	ranks[&"steady_hands"] = 25
	assert_true(SkillTree.can_rank_up(ranks, &"execution_line", 50))


func test_rank_up_returns_a_new_dictionary_even_when_refused() -> void:
	var ranks: Dictionary[StringName, int] = {&"steady_hands": 1}
	var result: Dictionary[StringName, int] = SkillTree.rank_up(ranks, &"steady_hands", 50)
	assert_eq(ranks[&"steady_hands"], 1)
	assert_eq(result[&"steady_hands"], 2)
	result[&"quick_draw"] = 1
	assert_false(ranks.has(&"quick_draw"))
	result = SkillTree.rank_up(ranks, &"steady_hands", 1)
	result[&"quick_draw"] = 1
	assert_false(ranks.has(&"quick_draw"))


func test_unknown_node_is_refused() -> void:
	var ranks: Dictionary[StringName, int] = {}
	assert_false(SkillTree.can_rank_up(ranks, &"missing_skill", 50))
	assert_eq(SkillTree.rank_up(ranks, &"missing_skill", 50), ranks)


func test_respec_returns_all_points_including_level_bonuses() -> void:
	var ranks: Dictionary[StringName, int] = {&"steady_hands": 3, &"thick_skin": 2}
	assert_eq(SkillTree.points_available(10, ranks), 5)
	ranks = SkillTree.respec()
	assert_true(ranks.is_empty())
	assert_eq(SkillTree.points_available(10, ranks), 10)
	assert_eq(SkillTree.points_available(50, ranks), 54)

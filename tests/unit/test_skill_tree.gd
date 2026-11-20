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


func test_keystone_needs_its_gate_in_its_own_branch() -> void:
	var gate: int = (Content.get_item(&"skills", &"dead_center") as SkillNodeData).branch_points_needed
	assert_gt(gate, 0)
	# Hand-built ranks exercise gates beyond the named nodes' current capacity.
	var ranks: Dictionary[StringName, int] = {&"steady_hands": gate - 1, &"thick_skin": 5}
	assert_eq(SkillTree.points_in_branch(ranks, &"Marksman"), gate - 1)
	assert_eq(SkillTree.points_in_branch(ranks, &"Survivor"), 5)
	assert_false(SkillTree.can_rank_up(ranks, &"dead_center", 50))
	ranks[&"steady_hands"] = gate
	assert_true(SkillTree.can_rank_up(ranks, &"dead_center", 50))
	assert_eq(SkillTree.rank_up(ranks, &"dead_center", 50).get(&"dead_center"), 1)
	assert_false(SkillTree.can_rank_up(ranks, &"dead_center", 2))


func test_capstone_needs_its_gate_counting_the_keystone() -> void:
	var gate: int = (Content.get_item(&"skills", &"execution_line") as SkillNodeData).branch_points_needed
	var ranks: Dictionary[StringName, int] = {&"steady_hands": gate - 2, &"dead_center": 1}
	assert_false(SkillTree.can_rank_up(ranks, &"execution_line", 50))
	ranks[&"steady_hands"] = gate - 1
	assert_true(SkillTree.can_rank_up(ranks, &"execution_line", 50))


func test_only_ranks_added_since_the_save_come_off() -> void:
	var saved: Dictionary[StringName, int] = {&"steady_hands": 1}
	var pending: Dictionary[StringName, int] = {&"steady_hands": 2, &"quick_draw": 1}
	assert_true(SkillTree.can_rank_down(pending, saved, &"steady_hands"))
	assert_true(SkillTree.can_rank_down(pending, saved, &"quick_draw"))
	assert_false(SkillTree.can_rank_down(pending, saved, &"weak_spot"))
	pending = SkillTree.rank_down(pending, saved, &"steady_hands")
	assert_eq(pending[&"steady_hands"], 1)
	assert_false(SkillTree.can_rank_down(pending, saved, &"steady_hands"), "saved ranks only go with Reset")
	pending = SkillTree.rank_down(pending, saved, &"quick_draw")
	assert_false(pending.has(&"quick_draw"), "a rank taken to 0 leaves no key")


func test_removing_a_rank_that_holds_up_a_keystone_is_refused() -> void:
	var gate: int = (Content.get_item(&"skills", &"dead_center") as SkillNodeData).branch_points_needed
	var saved: Dictionary[StringName, int] = {}
	var pending: Dictionary[StringName, int] = {&"steady_hands": gate, &"dead_center": 1}
	assert_false(SkillTree.can_rank_down(pending, saved, &"steady_hands"))
	assert_eq(SkillTree.rank_down(pending, saved, &"steady_hands"), pending)
	assert_true(SkillTree.can_rank_down(pending, saved, &"dead_center"))
	pending = SkillTree.rank_down(pending, saved, &"dead_center")
	assert_true(SkillTree.can_rank_down(pending, saved, &"steady_hands"))


func test_rank_down_returns_a_copy() -> void:
	var saved: Dictionary[StringName, int] = {}
	var pending: Dictionary[StringName, int] = {&"steady_hands": 2}
	var result: Dictionary[StringName, int] = SkillTree.rank_down(pending, saved, &"steady_hands")
	assert_eq(pending[&"steady_hands"], 2)
	assert_eq(result[&"steady_hands"], 1)


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

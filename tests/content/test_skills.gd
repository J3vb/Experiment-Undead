## Validates skill content, design values, stack stat names, rules, prerequisite graphs and branch gates.
extends GutTest

const BRANCHES: Array[StringName] = [&"Marksman", &"Survivor", &"Tinkerer"]
## Lowered from the design's 15 and 25 until F-90 adds nodes (the person's pick, 2026-11-20).
const KEYSTONE_GATE: int = 8
const CAPSTONE_GATE: int = 11


func test_every_node_loads_and_has_valid_fields() -> void:
	assert_eq(Content.ids(&"skills").size(), 20)
	for node_id: StringName in Content.ids(&"skills"):
		var node: SkillNodeData = Content.get_item(&"skills", node_id) as SkillNodeData
		assert_not_null(node, String(node_id))
		if node == null:
			continue
		assert_eq(node.id, node_id, "id matches Content's filename id")
		assert_eq(node.resource_path.get_file().get_basename(), String(node.id))
		assert_false(node.display_name.is_empty(), String(node_id) + " has a name")
		assert_false(node.description.is_empty(), String(node_id) + " has a description")
		assert_has(BRANCHES, node.branch)
		assert_gte(node.max_ranks, 1)
		assert_gte(node.column, 0)
		assert_has([0, KEYSTONE_GATE, CAPSTONE_GATE], node.branch_points_needed)
		if node.stat != &"":
			assert_true(node.description.contains("{v}"), String(node_id) + " has per-rank text")
			assert_gt(node.per_rank, 0.0)
		if node.branch_points_needed == 0:
			assert_between(node.row, 0, 2)
		else:
			assert_eq(node.row, 3 if node.branch_points_needed == KEYSTONE_GATE else 4)
			assert_ne(node.rule, SkillNodeData.Rule.NONE, String(node_id) + " keystones and capstones are rules")
			assert_eq(node.stat != &"", node_id == &"undying", String(node_id) + " only Undying also has a stat")
			assert_eq(node.max_ranks, 1)


func test_named_normal_nodes_match_design_table() -> void:
	# id: [branch, max ranks, stack stat (gear affix names), per-rank value in description units, op].
	var expected: Dictionary = {
		&"steady_hands": [&"Marksman", 3, &"recoil_pct", 5.0, "increased"],
		&"quick_draw": [&"Marksman", 3, &"ads_pct", 5.0, "increased"],
		&"weak_spot": [&"Marksman", 3, &"hs_pct", 5.0, "increased"],
		&"fast_hands": [&"Marksman", 3, &"reload_pct", 5.0, "increased"],
		&"deep_pockets": [&"Marksman", 2, &"deep_reserve", 10.0, "increased"],
		&"thick_skin": [&"Survivor", 3, &"max_health", 10.0, "flat"],
		&"second_breath": [&"Survivor", 3, &"regen_delay", 0.3, "flat"],
		&"light_feet": [&"Survivor", 2, &"sprint_speed", 5.0, "increased"],
		&"sturdy": [&"Survivor", 2, &"explosion_guard", 25.0, "increased"],
		&"scrounger": [&"Tinkerer", 3, &"points_earned", 5.0, "increased"],
		&"lucky_find": [&"Tinkerer", 3, &"loot_luck", 5.0, "increased"],
		&"overtime": [&"Tinkerer", 2, &"power_up_duration", 3.0, "flat"],
		&"gadgeteer": [&"Tinkerer", 3, &"ability_cooldown", 8.0, "increased"],
		&"carpenter": [&"Tinkerer", 2, &"repair_speed", 30.0, "increased"],
	}
	for node_id: StringName in expected:
		var node: SkillNodeData = Content.get_item(&"skills", node_id) as SkillNodeData
		assert_not_null(node, String(node_id))
		if node == null:
			continue
		var values: Array = expected[node_id]
		assert_eq(node.branch, values[0], String(node_id))
		assert_eq(node.max_ranks, values[1], String(node_id))
		assert_eq(node.stat, values[2], String(node_id))
		assert_almost_eq(node.per_rank, values[3], 0.0001, String(node_id))
		assert_eq(node.op, values[4], String(node_id))
		assert_eq(node.rule, SkillNodeData.Rule.NONE, String(node_id))
		assert_eq(node.branch_points_needed, 0)


func test_each_rule_belongs_to_exactly_one_skill() -> void:
	var owners: Dictionary[int, StringName] = {}
	for node_id: StringName in Content.sorted_ids(&"skills"):
		var node: SkillNodeData = Content.get_item(&"skills", node_id) as SkillNodeData
		if node.rule == SkillNodeData.Rule.NONE:
			continue
		assert_false(owners.has(node.rule), "%s and %s share a rule" % [owners.get(node.rule, &""), node_id])
		owners[node.rule] = node_id
	assert_eq(owners.size(), SkillNodeData.Rule.size() - 1, "every rule has its skill")
	assert_eq(owners[SkillNodeData.Rule.UNDYING], &"undying")


func test_each_branch_has_its_named_keystone_and_capstone() -> void:
	var expected: Dictionary = {
		&"Marksman": [&"dead_center", &"execution_line"],
		&"Survivor": [&"last_stand", &"undying"],
		&"Tinkerer": [&"bargain_hunter", &"chain_supply"],
	}
	for branch: StringName in BRANCHES:
		var keystones: Array[StringName] = []
		var capstones: Array[StringName] = []
		for node_id: StringName in Content.ids(&"skills"):
			var node: SkillNodeData = Content.get_item(&"skills", node_id) as SkillNodeData
			if node.branch != branch:
				continue
			if node.row == 3:
				keystones.append(node_id)
			elif node.row == 4:
				capstones.append(node_id)
		assert_eq(keystones, [expected[branch][0]], String(branch) + " keystone")
		assert_eq(capstones, [expected[branch][1]], String(branch) + " capstone")


func test_prerequisites_exist_and_have_no_cycles() -> void:
	for node_id: StringName in Content.ids(&"skills"):
		_check_prerequisites(node_id, [])


func _check_prerequisites(node_id: StringName, path: Array[StringName]) -> void:
	assert_false(path.has(node_id), "Prerequisite cycle: %s -> %s" % [path, node_id])
	if path.has(node_id):
		return
	var node: SkillNodeData = Content.get_item(&"skills", node_id) as SkillNodeData
	var next_path: Array[StringName] = path.duplicate()
	next_path.append(node_id)
	for required_id: StringName in node.requires:
		assert_has(Content.ids(&"skills"), required_id, String(node_id) + " prerequisite exists")
		if Content.ids(&"skills").has(required_id):
			_check_prerequisites(required_id, next_path)


func test_every_gate_can_be_reached_with_the_other_nodes_in_its_branch() -> void:
	for node_id: StringName in Content.ids(&"skills"):
		var node: SkillNodeData = Content.get_item(&"skills", node_id) as SkillNodeData
		var others: int = 0
		for other_id: StringName in Content.ids(&"skills"):
			var other: SkillNodeData = Content.get_item(&"skills", other_id) as SkillNodeData
			if other.branch == node.branch and other.id != node.id and other.row < node.row:
				others += other.max_ranks
		assert_gte(others, node.branch_points_needed, String(node_id) + " gate is reachable")


func test_row_and_column_are_unique_inside_a_branch() -> void:
	var seen: Dictionary[String, StringName] = {}
	for node_id: StringName in Content.ids(&"skills"):
		var node: SkillNodeData = Content.get_item(&"skills", node_id) as SkillNodeData
		var key: String = "%s/%d/%d" % [node.branch, node.row, node.column]
		assert_false(seen.has(key), "%s shares its place with %s" % [node_id, seen.get(key, &"")])
		seen[key] = node_id

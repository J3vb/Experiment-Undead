## Validates skill content, design values, prerequisite graphs and branch gates.
extends GutTest

const BRANCHES: Array[StringName] = [&"Marksman", &"Survivor", &"Tinkerer"]


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
		assert_has([0, 15, 25], node.branch_points_needed)
		if node.stat != &"":
			assert_true(node.description.contains("{v}"), String(node_id) + " has per-rank text")
			assert_gt(node.per_rank, 0.0)
		if node.branch_points_needed == 0:
			assert_between(node.row, 0, 2)
		else:
			assert_eq(node.row, 3 if node.branch_points_needed == 15 else 4)
			assert_eq(node.stat, &"")
			assert_eq(node.max_ranks, 1)


func test_named_normal_nodes_match_design_table() -> void:
	# id: [branch, max ranks, stat, per-rank value in description units].
	var expected: Dictionary = {
		&"steady_hands": [&"Marksman", 3, &"recoil", 5.0],
		&"quick_draw": [&"Marksman", 3, &"ads_time", 5.0],
		&"weak_spot": [&"Marksman", 3, &"head_damage", 5.0],
		&"fast_hands": [&"Marksman", 3, &"reload_time", 5.0],
		&"deep_pockets": [&"Marksman", 2, &"reserve_ammo", 10.0],
		&"thick_skin": [&"Survivor", 3, &"max_health", 10.0],
		&"second_breath": [&"Survivor", 3, &"regen_delay", 0.3],
		&"light_feet": [&"Survivor", 2, &"sprint_speed", 5.0],
		&"sturdy": [&"Survivor", 2, &"self_explosive_damage", 25.0],
		&"scrounger": [&"Tinkerer", 3, &"points", 5.0],
		&"lucky_find": [&"Tinkerer", 3, &"loot_luck", 5.0],
		&"overtime": [&"Tinkerer", 2, &"power_up_duration", 3.0],
		&"gadgeteer": [&"Tinkerer", 3, &"ability_cooldown", 8.0],
		&"carpenter": [&"Tinkerer", 2, &"repair_speed", 30.0],
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
		assert_eq(node.branch_points_needed, 0)


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
			if node.branch_points_needed == 15:
				keystones.append(node_id)
			elif node.branch_points_needed == 25:
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

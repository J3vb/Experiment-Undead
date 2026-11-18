## Gear bases resolve to real visuals and gear affixes preserve the design tables.
extends GutTest

const GATES: Array[int] = [1, 8, 15, 22, 30]
const SLOTS: Array[StringName] = [&"vest", &"charm", &"implant"]
const MODELS: Array[StringName] = [
	&"vest_light",
	&"vest_medium",
	&"vest_heavy",
	&"charm_dog_tags",
	&"charm_vial",
	&"charm_keycard",
	&"charm_dosimeter",
	&"charm_coin",
	&"implant_reflex",
	&"implant_lung",
	&"implant_spine",
	&"implant_ocular",
	&"implant_relay",
]
const RANGES: Dictionary[StringName, Vector3] = {
	&"max_health": Vector3(10, 40, 100),
	&"damage_reduction": Vector3(3, 10, 70),
	&"explosion_guard": Vector3(15, 50, 60),
	&"regen_delay": Vector3(0.3, 1.0, 100),
	&"grab_escape": Vector3(15, 40, 60),
	&"fast_revive": Vector3(15, 40, 60),
	&"points_earned": Vector3(3, 10, 80),
	&"loot_luck": Vector3(5, 20, 80),
	&"power_up_duration": Vector3(2, 5, 90),
	&"power_up_chance": Vector3(5, 15, 60),
	&"scrap_find": Vector3(5, 20, 70),
	&"vault_favour": Vector3(2, 6, 30),
	&"ability_power": Vector3(8, 25, 90),
	&"grenade_damage": Vector3(15, 40, 90),
	&"skill_rank": Vector3(1, 1, 40),
	&"ability_cooldown": Vector3(5, 15, 100),
	&"extra_grenade": Vector3(1, 1, 25),
	&"tactical_recharge": Vector3(10, 30, 70),
	&"move_speed": Vector3(3, 8, 70),
	&"sprint_duration": Vector3(15, 40, 60),
	&"all_damage": Vector3(2, 6, 50),
	&"headshot_focus": Vector3(4, 12, 50),
	&"reload_focus": Vector3(4, 10, 60),
	&"mule": Vector3(5, 15, 50),
}


func test_thirteen_bases_are_indexed_and_reference_matching_visuals() -> void:
	var paths: PackedStringArray = _files("res://content/loot/gear")
	assert_eq(paths.size(), 13)
	var seen: Array[StringName] = []
	for path: String in paths:
		var base: GearBaseData = load(path) as GearBaseData
		assert_not_null(base, path)
		if base == null:
			continue
		assert_eq(String(base.id), path.get_file().get_basename())
		assert_has(MODELS, base.id)
		assert_false(seen.has(base.id), "base ids are unique")
		seen.append(base.id)
		assert_same(Content.get_item(&"loot", base.id), base)
		assert_eq(String(base.slot), String(base.id).get_slice("_", 0))
		assert_eq(base.visual_id, base.id)
		assert_ne(base.display_name, "")
		assert_false(base.loot_tags.is_empty())
		assert_eq(base.unlock_level, 1, "provisional starting gear gate")
		assert_eq(base.drop_weight, 100.0, "provisional equal base weights")
		var visual: GearVisual = Content.get_item(&"gear_visuals", base.visual_id) as GearVisual
		assert_not_null(visual, path + " visual exists")
		if visual != null:
			assert_eq(visual.slot, StringName(base.slot))
			assert_same(GearVisual.find(base.visual_id), visual)
	assert_eq(seen.size(), MODELS.size())


func test_unknown_visual_and_fallback_slot_return_no_resource() -> void:
	assert_null(GearVisual.find(&"unknown_visual"))
	assert_null(GearVisual.fallback(&"unknown_slot"))


func test_visual_scenes_load_and_attach_to_the_player_skeleton() -> void:
	var packed: PackedScene = load("res://assets/models/characters/player.glb") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var player: Node = packed.instantiate()
	var skeletons: Array[Node] = player.find_children("*", "Skeleton3D", true, false)
	assert_eq(skeletons.size(), 1)
	if skeletons.size() == 1:
		var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
		assert_eq(skeleton.get_bone_count(), 22)
		for id: StringName in Content.ids(&"gear_visuals"):
			_check_visual(id, skeleton)
	player.free()
	assert_eq(Content.ids(&"gear_visuals").size(), 13)
	assert_eq(_files("res://content/gear_visuals").size(), 13)


func test_gear_affixes_have_five_equal_rising_tiers() -> void:
	var paths: PackedStringArray = _files("res://content/loot/affixes/gear")
	assert_eq(paths.size(), 24)
	var families: Array[StringName] = []
	for path: String in paths:
		var affix: AffixData = load(path) as AffixData
		assert_not_null(affix, path)
		if affix == null:
			continue
		assert_eq(String(affix.id), path.get_file().get_basename())
		assert_same(Content.get_item(&"loot", affix.id), affix)
		assert_true(affix.single_value or affix.text.contains("{v}"), String(affix.id))
		assert_ne(affix.family, &"")
		assert_false(families.has(affix.family), "each gear affix has its own family")
		families.append(affix.family)
		assert_true(affix.exclusive_families.is_empty())
		assert_ne(affix.stat, &"")
		assert_has(["increased", "more", "flat", "proc"], affix.op)
		assert_gt(affix.step, 0.0)
		assert_eq(affix.tiers.size(), 5, String(affix.id))
		_check_tiers(affix)


func test_gear_affix_ranges_weights_kinds_and_slots_match_the_tables() -> void:
	var prefixes: Array[StringName] = [
		&"max_health",
		&"damage_reduction",
		&"points_earned",
		&"loot_luck",
		&"ability_power",
		&"grenade_damage",
		&"skill_rank",
		&"all_damage",
		&"headshot_focus",
	]
	var ids: Array[StringName] = []
	ids.assign(RANGES.keys())
	for index: int in ids.size():
		var id: StringName = ids[index]
		var affix: AffixData = Content.get_item(&"loot", id) as AffixData
		var values: Vector3 = RANGES[id]
		assert_almost_eq(affix.tiers[0].low, float(values.x), 0.00001, String(id))
		assert_almost_eq(affix.tiers[4].high, float(values.y), 0.00001, String(id))
		assert_eq(affix.weight, float(values.z), String(id))
		assert_eq(affix.kind, "prefix" if prefixes.has(id) else "suffix", String(id))
		var expected_slots: Array[StringName] = SLOTS.duplicate()
		if index < 18:
			expected_slots.assign([SLOTS[floori(index / 6.0)]])
		assert_eq(affix.slots, expected_slots, String(id))
		assert_eq(affix.min_rarity, &"rare" if id in [&"skill_rank", &"extra_grenade", &"vault_favour"] else &"common")


func test_shared_gear_bonus_stat_keys_match_runtime_consumers() -> void:
	var expected: Dictionary[StringName, StringName] = {
		&"all_damage": &"dmg_pct",
		&"reload_focus": &"reload_pct",
		&"headshot_focus": &"hs_pct",
		&"sprint_duration": &"sprint_time",
		&"mule": &"deep_reserve",
	}
	for id: StringName in expected:
		var affix: AffixData = Content.get_item(&"loot", id) as AffixData
		assert_eq(affix.stat, expected[id], String(id))
		assert_eq(affix.op, "increased", String(id))


func test_single_value_lines_keep_their_fixed_value_and_level_gate() -> void:
	for id: StringName in RANGES:
		var affix: AffixData = Content.get_item(&"loot", id) as AffixData
		var gate: int = {&"skill_rank": 15, &"extra_grenade": 22}.get(id, 1)
		assert_eq(affix.min_ilvl, gate, String(id))
		assert_eq(affix.single_value, gate > 1, String(id))
		if affix.single_value:
			for tier: AffixTier in affix.tiers:
				assert_eq(tier.low, 1.0)
				assert_eq(tier.high, 1.0)


func _check_visual(id: StringName, skeleton: Skeleton3D) -> void:
	var visual: GearVisual = Content.get_item(&"gear_visuals", id) as GearVisual
	assert_not_null(visual, String(id))
	if visual == null:
		return
	assert_eq(visual.id, id)
	assert_eq(String(visual.id), visual.resource_path.get_file().get_basename())
	assert_has(MODELS, visual.id)
	assert_has(SLOTS, visual.slot)
	assert_eq(visual.set_id, &"")
	assert_gte(skeleton.find_bone(visual.attach), 0, String(id) + " attachment bone exists")
	assert_not_null(visual.scene, String(id) + " scene loads")
	if visual.scene != null:
		assert_eq(visual.scene.resource_path, "res://assets/models/gear/%s.glb" % id)
		var model: Node = visual.scene.instantiate()
		assert_true(model is Node3D, String(id) + " scene instantiates")
		model.free()


func _check_tiers(affix: AffixData) -> void:
	for index: int in affix.tiers.size():
		var tier: AffixTier = affix.tiers[index]
		assert_eq(tier.min_ilvl, GATES[index])
		assert_gte(tier.high, tier.low)
		if not affix.single_value:
			assert_gt(tier.high, tier.low)
		assert_almost_eq(tier.high - tier.low, affix.tiers[0].high - affix.tiers[0].low, 0.00001)
		if index > 0:
			assert_almost_eq(tier.low, affix.tiers[index - 1].high, 0.00001)


func _files(path: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(path)
	assert_not_null(dir, path + " exists")
	if dir != null:
		for file: String in dir.get_files():
			var clean: String = file.trim_suffix(".remap")
			if clean.ends_with(".tres"):
				paths.append(path.path_join(clean))
	return paths


func test_rarities_pick_field_plated_and_oriel_tiers_and_tiered_visuals_have_three_scenes() -> void:
	var tiers: Dictionary[StringName, int] = {
		&"common": 0, &"uncommon": 0, &"rare": 1, &"epic": 1, &"legendary": 2, &"prototype": 2
	}
	for rarity: StringName in tiers:
		var look: RarityLook = Content.get_item(&"looks", rarity) as RarityLook
		assert_eq(look.tier, tiers[rarity], String(rarity))
	for visual_id: StringName in Content.ids(&"gear_visuals"):
		var visual: GearVisual = GearVisual.find(visual_id)
		assert_true(visual.tier_scenes.size() in [0, 3], "%s has no tier scenes or all three" % visual_id)
		for scene: PackedScene in visual.tier_scenes:
			assert_not_null(scene, String(visual_id))

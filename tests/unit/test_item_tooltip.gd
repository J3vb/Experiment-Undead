## Item details preserve rolls, tolerate unknown bonuses and compare numbers in both directions.
extends GutTest

const TOOLTIP: PackedScene = preload("res://systems/ui/item_tooltip.tscn")

var tooltip: ItemTooltip


func before_each() -> void:
	tooltip = TOOLTIP.instantiate() as ItemTooltip
	add_child_autofree(tooltip)


func test_known_affix_uses_rolled_value_and_full_content_range() -> void:
	var item: Dictionary = _item("rifle_ar", [["reload_pct", 2, 2.0 / 3.0]])
	tooltip.show_item(item)
	var line: RichTextLabel = tooltip.affixes.get_child(0) as RichTextLabel
	assert_eq(line.get_parsed_text(), "+12% reload speed (8-20)")
	assert_string_contains(line.text, "[color=#8fa3a8](8-20)[/color]")
	assert_eq(tooltip.item_name.text, "AR-17")
	assert_eq(tooltip.level_label.text, "Item level 17")
	assert_string_contains(tooltip.rarity_label.text, "Rare")
	assert_eq(tooltip.rarity_label.text.count("•"), 3)
	var rarity: RarityData = Content.get_item(&"loot", &"rare") as RarityData
	assert_eq(tooltip.item_name.get_theme_color("font_color"), rarity.colour)
	assert_eq(item.aff[0], ["reload_pct", 2, 2.0 / 3.0], "Rendering does not mutate the saved roll")


func test_unknown_affix_is_grey_inactive_and_unknown_base_is_safe() -> void:
	tooltip.show_item(_item("missing_base", [["future_affix", 1, 0.5]]))
	var line: RichTextLabel = tooltip.affixes.get_child(0) as RichTextLabel
	assert_eq(line.get_parsed_text(), "Inactive bonus")
	assert_eq(line.text, "[color=#8fa3a8]Inactive bonus[/color]")
	assert_eq(tooltip.item_name.text, "Unknown item")
	assert_eq(tooltip.stats.get_child_count(), 0)


func test_compare_marks_better_and_worse_base_stats_and_lower_ads_is_better() -> void:
	tooltip.show_item(_item("rifle_ar"), _item("talon_dmr"))
	assert_false(_stat_value(0).text.contains("↓"), "Arrows stay hidden until compare is held")
	tooltip.set_comparing(true)
	assert_string_contains(_stat_value(0).text, "↓")
	assert_eq(_stat_value(0).get_theme_color("font_color"), ItemTooltip.WORSE)
	assert_string_contains(_stat_value(1).text, "↑")
	assert_eq(_stat_value(1).get_theme_color("font_color"), ItemTooltip.BETTER)
	assert_string_contains(_stat_value(3).text, "↑")
	assert_string_contains(tooltip.comparison.text, "MR-28 (equipped)")
	tooltip.set_comparing(false)
	assert_false(_stat_value(0).text.contains("↓"))
	assert_eq(tooltip.comparison.text, "Hold Shift / X to compare")


func test_same_base_rolled_stats_match_runtime_numbers_and_comparison_arrows() -> void:
	var strong: Dictionary = _item(
		"rifle_ar", [["dmg_pct", 5, 1.0], ["fire_rate_pct", 5, 1.0], ["mag_pct", 5, 1.0], ["ads_pct", 5, 1.0]]
	)
	var weak: Dictionary = _item(
		"rifle_ar", [["dmg_pct", 1, 0.0], ["fire_rate_pct", 1, 0.0], ["mag_pct", 1, 0.0], ["ads_pct", 1, 0.0]]
	)
	strong.ilvl = 30
	weak.ilvl = 30
	strong.rar = "legendary"
	weak.rar = "legendary"
	var saved: Dictionary = strong.duplicate(true)
	tooltip.show_item(strong, weak)
	tooltip.set_comparing(true)
	var expected: Array[String] = ["39.1 ↑", "748 ↑", "39 ↑", "0.18 s ↑"]
	for index: int in expected.size():
		assert_eq(_stat_value(index).text, expected[index])
		assert_eq(_stat_value(index).get_theme_color("font_color"), ItemTooltip.BETTER)
	assert_eq(strong, saved, "Runtime presentation leaves the saved item unchanged")
	assert_eq(Content.weapon(&"rifle_ar").damage, 34.0, "Runtime presentation leaves shared content unchanged")
	tooltip.show_item(weak, strong)
	for index: int in expected.size():
		assert_string_contains(_stat_value(index).text, "↓")
		assert_eq(_stat_value(index).get_theme_color("font_color"), ItemTooltip.WORSE)


func test_rolls_can_reverse_the_order_of_different_weapon_bases() -> void:
	tooltip.set_comparing(true)
	tooltip.show_item(_item("mako_pdw"), _item("rifle_ar"))
	assert_string_contains(_stat_value(0).text, "↓")
	tooltip.show_item(_item("mako_pdw", [["dmg_pct", 5, 1.0]]), _item("rifle_ar"))
	assert_eq(_stat_value(0).text, "36.05 ↑")
	tooltip.show_item(_item("pistol_service"), _item("talon_dmr"))
	assert_string_contains(_stat_value(2).text, "↓")
	tooltip.show_item(_item("pistol_service", [["mag_pct", 5, 1.0]]), _item("talon_dmr"))
	assert_eq(_stat_value(2).text, "16 ↑")
	tooltip.show_item(_item("talon_dmr"), _item("rifle_ar"))
	assert_string_contains(_stat_value(3).text, "↓")
	tooltip.show_item(_item("talon_dmr", [["ads_pct", 5, 1.0]]), _item("rifle_ar"))
	assert_eq(_stat_value(3).text, "0.21 s ↑")


func test_unknown_and_invalid_weapon_bonuses_leave_runtime_base_stats_unchanged() -> void:
	tooltip.show_item(_item("rifle_ar", [["future_affix", 1, 0.5], ["dmg_pct", 99, 0.5]]))
	assert_eq(_stat_value(0).text, "34")
	assert_eq(_stat_value(1).text, "680")
	assert_eq(_stat_value(2).text, "30")
	assert_eq(_stat_value(3).text, "0.22 s")
	for line: RichTextLabel in tooltip.affixes.get_children():
		assert_eq(line.get_parsed_text(), "Inactive bonus")


func test_compare_matches_affix_ids_and_leaves_the_range_grey() -> void:
	var equipped: Dictionary = _item("rifle_ar", [["reload_pct", 2, 0.0]])
	tooltip.show_item(_item("rifle_ar", [["reload_pct", 2, 1.0]]), equipped)
	tooltip.set_comparing(true)
	var line: RichTextLabel = tooltip.affixes.get_child(0) as RichTextLabel
	assert_eq(line.get_parsed_text(), "+12.8% reload speed ↑ (8-20)")
	assert_string_contains(line.text, "[color=#7fd6e0]")
	tooltip.show_item(equipped, _item("rifle_ar", [["reload_pct", 2, 1.0]]))
	line = tooltip.affixes.get_child(0) as RichTextLabel
	assert_eq(line.get_parsed_text(), "+10.4% reload speed ↓ (8-20)")
	assert_string_contains(line.text, "[color=#ff9f1c]")
	assert_string_contains(line.text, "[color=#8fa3a8](8-20)[/color]")


func test_implicit_range_comes_from_rarity_and_bad_tier_is_inactive() -> void:
	var item: Dictionary = _item("rifle_ar", [["reload_pct", 99, 0.5]])
	item.imp = ["deep_reserve", 0.5]
	tooltip.show_item(item)
	assert_eq((tooltip.affixes.get_child(0) as RichTextLabel).get_parsed_text(), "Inactive bonus")
	assert_eq((tooltip.affixes.get_child(1) as RichTextLabel).get_parsed_text(), "+88% reserve ammo (75-100)")


func test_empty_equipped_slot_and_equal_stats_have_no_compare_arrows() -> void:
	tooltip.show_item(_item("rifle_ar"))
	tooltip.set_comparing(true)
	assert_eq(tooltip.comparison.text, "No item equipped in this slot")
	assert_false(_stat_value(0).text.contains("↑"))
	tooltip.show_item(_item("rifle_ar"), _item("rifle_ar"))
	assert_false(_stat_value(0).text.contains("↑"))
	assert_false(_stat_value(0).text.contains("↓"))
	tooltip.show_item({})
	assert_eq(tooltip.item_name.text, "Select an item")
	assert_eq(tooltip.stats.get_child_count(), 0)
	assert_eq(tooltip.affixes.get_child_count(), 0)


func test_known_visual_gear_uses_its_name_and_actual_slot() -> void:
	var names: Dictionary[String, String] = {
		"vest_medium": "Salvager Vest", "charm_dog_tags": "Tether Tags", "implant_reflex": "Ridge Reflex"
	}
	for base: String in names:
		var item: Dictionary = _item(base)
		item.imp = null
		tooltip.show_item(item)
		assert_eq(tooltip.item_name.text, names[base])
		assert_eq(tooltip.stats.get_child_count(), 1)
		var slot: Label = tooltip.stats.get_child(0) as Label
		assert_eq(slot.text, "Slot: " + base.get_slice("_", 0).capitalize())


func test_gear_affix_value_and_range_render_with_null_implicit_ammo() -> void:
	var item: Dictionary = _item("vest_medium", [["max_health", 2, 0.5]])
	item.imp = null
	tooltip.show_item(item)
	assert_eq(tooltip.affixes.get_child_count(), 1)
	var line: RichTextLabel = tooltip.affixes.get_child(0) as RichTextLabel
	assert_eq(line.get_parsed_text(), "+19 max health (10-40)")
	assert_string_contains(line.text, "[color=#8fa3a8](10-40)[/color]")
	assert_null(item.imp)


func test_real_gear_rolls_render_every_bonus_and_compare_without_implicit_ammo() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 73021
	var base: GearBaseData = Content.get_item(&"loot", &"vest_medium") as GearBaseData
	var item: Dictionary = ItemRoller.roll_gear(rng, base, &"rare", 17)
	var equipped: Dictionary = ItemRoller.roll_gear(rng, base, &"rare", 17)
	assert_null(item.imp)
	tooltip.show_item(item, equipped)
	tooltip.set_comparing(true)
	assert_eq(tooltip.affixes.get_child_count(), item.aff.size())
	for line: RichTextLabel in tooltip.affixes.get_children():
		assert_false(line.get_parsed_text().contains("Inactive bonus"))
	assert_eq(tooltip.comparison.text, "Compared with Salvager Vest (equipped)")


func test_weapon_comparison_fits_a_390_pixel_column() -> void:
	tooltip.show_item(_item("rifle_ar"), _item("talon_dmr"))
	tooltip.set_comparing(true)
	tooltip.size = Vector2(390.0, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lte(tooltip.get_combined_minimum_size().x, 390.0)
	for row: Control in tooltip.stats.get_children():
		assert_lte(row.get_global_rect().end.x, tooltip.get_global_rect().end.x)
		assert_eq(row.get_child_count(), 3)
		assert_gte((row.get_child(1) as ProgressBar).size.x, 50.0)


func _item(base: String, aff: Array = []) -> Dictionary:
	return {"uid": "test", "base": base, "rar": "rare", "ilvl": 17, "aff": aff, "imp": []}


func _stat_value(index: int) -> Label:
	return tooltip.stats.get_child(index).get_child(2) as Label

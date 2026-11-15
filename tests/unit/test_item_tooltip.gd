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
	assert_eq(tooltip.item_name.text, "AR-7 Rifle")
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
	assert_string_contains(tooltip.comparison.text, "Talon DMR (equipped)")
	tooltip.set_comparing(false)
	assert_false(_stat_value(0).text.contains("↓"))
	assert_eq(tooltip.comparison.text, "Hold Shift / X to compare")


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


func _item(base: String, aff: Array = []) -> Dictionary:
	return {"uid": "test", "base": base, "rar": "rare", "ilvl": 17, "aff": aff, "imp": []}


func _stat_value(index: int) -> Label:
	return tooltip.stats.get_child(index).get_child(2) as Label

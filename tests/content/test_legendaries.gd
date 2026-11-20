## Every Legendary names a real base, a trait stat that has code, a sane range and a flavour line.
extends GutTest

## Trait stats with code that reads them. Step 2 moves this list to LegendaryTraits.STATS.
const KNOWN_STATS: Array[StringName] = [&"tidewater"]


func test_every_legendary_is_complete_and_points_at_a_real_base() -> void:
	var per_base: Dictionary[StringName, int] = {}
	var found: int = 0
	for id: StringName in Content.sorted_ids(&"loot"):
		var legendary: LegendaryData = Content.get_item(&"loot", id) as LegendaryData
		if legendary == null:
			continue
		found += 1
		assert_eq(legendary.id, id)
		assert_false(legendary.display_name.is_empty(), "%s has a name" % id)
		assert_false(legendary.flavour.is_empty(), "%s has a flavour line" % id)
		assert_true(legendary.text.contains("{v}"), "%s text shows the rolled value" % id)
		assert_lt(legendary.low, legendary.high, "%s stores low < high" % id)
		assert_gt(legendary.step, 0.0)
		assert_true(KNOWN_STATS.has(legendary.stat), "%s trait stat has code" % id)
		var base: StringName = legendary.base_id
		if Content.has(&"weapons", base):
			assert_false(Content.weapon(base).loot_tags.has(&"prototype"), "%s is not on a Prototype" % id)
			assert_false(String(base).ends_with("_reforged"))
		else:
			assert_true(Content.get_item(&"loot", base) is GearBaseData, "%s base %s exists" % [id, base])
		per_base[base] = per_base.get(base, 0) + 1
		assert_lte(per_base[base], 2, "At most two Legendaries per base")
	assert_gt(found, 0)


func test_trait_stats_are_unique() -> void:
	var stats: Array[StringName] = []
	for id: StringName in Content.sorted_ids(&"loot"):
		var legendary: LegendaryData = Content.get_item(&"loot", id) as LegendaryData
		if legendary:
			assert_false(stats.has(legendary.stat), "%s stat is its own" % id)
			stats.append(legendary.stat)

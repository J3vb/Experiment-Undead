## Checks progression balance content and that gameplay leaves the shared Resource intact.
extends GutTest

var rules: XpRules


func before_each() -> void:
	rules = load("res://content/progression/xp_rules.tres") as XpRules


func test_xp_rules_loads_with_positive_balance_values() -> void:
	assert_not_null(rules)
	if rules == null:
		return
	for field: StringName in [
		&"headshot_kill_bonus", &"round_clear_xp_per_round", &"level_base", &"level_exponent", &"round_to", &"max_level"
	]:
		assert_gt(float(rules.get(field)), 0.0, "%s > 0" % field)
	assert_eq(rules.bonus_point_levels, [10, 20, 30, 40, 50])


func test_progression_does_not_mutate_rules() -> void:
	var before: XpRules = rules.duplicate(true) as XpRules
	var progression: ProgressionService = ProgressionService.new()
	autofree(progression)
	var player: Player = Player.new()
	autofree(player)
	progression.set_start_total(player, 500)
	progression.add_xp(player, 2000000)
	assert_same(progression.rules, rules)
	for property: Dictionary in rules.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_eq(rules.get(property["name"]), before.get(property["name"]), property["name"])

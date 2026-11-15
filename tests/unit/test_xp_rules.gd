## Checks every level against the balance CSV, including threshold boundaries.
extends GutTest

const RULES: XpRules = preload("res://content/progression/xp_rules.tres")
const BALANCE_PATH: String = "res://docs/design/balance/xp_and_levels.csv"


func test_all_levels_match_balance_csv() -> void:
	var file: FileAccess = FileAccess.open(BALANCE_PATH, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var levels_checked: int = 0
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 4 or not row[0].is_valid_int():
			continue
		var level: int = row[0].to_int()
		var total: int = row[2].to_int()
		levels_checked += 1
		assert_eq(level, levels_checked, "CSV covers levels in order")
		assert_eq(RULES.xp_to_next(level), row[1].to_int(), "XP to next at level %d" % level)
		assert_eq(RULES.total_xp_for_level(level), total, "Total XP to reach %d" % level)
		assert_eq(RULES.skill_points_for_level(level), row[3].to_int(), "Skill points at %d" % level)
		assert_eq(RULES.level_for_total_xp(total), level, "Exact threshold at %d" % level)
		assert_eq(RULES.level_for_total_xp(total - 1), maxi(level - 1, 1), "One XP below %d" % level)
	assert_eq(levels_checked, 50)


func test_level_and_skill_points_are_capped() -> void:
	assert_eq(RULES.level_for_total_xp(2000000000), 50)
	assert_eq(RULES.total_xp_for_level(51), 1444150)
	assert_eq(RULES.xp_to_next(51), 0)
	assert_eq(RULES.skill_points_for_level(50), 54)
	assert_eq(RULES.skill_points_for_level(51), 54)
	assert_eq(RULES.level_for_total_xp(-1), 1)

## Every gun has a FeelData inside the game-feel doc's validator ranges.
extends GutTest

const FEEL_DIR: String = "res://content/feel"
const WEAPON_DIR: String = "res://content/weapons"


func _tres(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file: String in DirAccess.get_files_at(directory):
		var clean: String = file.trim_suffix(".remap")
		if clean.get_extension() == "tres":
			paths.append(directory.path_join(clean))
	return paths


func test_every_weapon_has_feel() -> void:
	var paths: PackedStringArray = _tres(WEAPON_DIR)
	assert_gt(paths.size(), 0, "weapons found")
	for path: String in paths:
		var weapon: WeaponData = load(path) as WeaponData
		assert_not_null(weapon, path)
		assert_not_null(weapon.feel, path + " has a feel class file")


func test_reforged_shares_base_feel() -> void:
	for path: String in _tres(WEAPON_DIR):
		var weapon: WeaponData = load(path) as WeaponData
		if weapon.upgraded:
			assert_eq(weapon.upgraded.feel, weapon.feel, path + " Reforged copy uses the base feel")


func test_feel_values_in_validator_ranges() -> void:
	var count: int = 0
	for path: String in _tres(FEEL_DIR):
		var feel: FeelData = load(path) as FeelData
		if feel == null:
			continue
		count += 1
		assert_between(feel.view_kick_pitch, 0.0, 3.0, path + " view_kick_pitch")
		assert_between(feel.view_kick_return_ms, 40.0, 250.0, path + " view_kick_return_ms")
		assert_between(feel.fire_trauma, 0.0, 0.35, path + " fire_trauma")
		assert_between(feel.fov_punch_deg, -4.0, 4.0, path + " fov_punch_deg")
		assert_between(feel.kill_hitstop_ms, 0.0, 100.0, path + " kill_hitstop_ms")
		if feel.fov_punch_deg != 0.0:
			assert_gt(feel.fov_punch_ms, 0.0, path + " fov_punch_ms > 0 when it punches")
	assert_eq(count, 7, "seven weapon class files")


func test_feedback_rules_in_range() -> void:
	var rules: FeedbackRules = load(FEEL_DIR.path_join("feedback_rules.tres")) as FeedbackRules
	assert_not_null(rules)
	assert_gt(rules.trauma_decay, 0.0)
	for value: float in [rules.fire_trauma_cap, rules.hit_trauma, rules.round_start_trauma, rules.ads_trauma_mult]:
		assert_between(value, 0.0, 1.0)
	assert_between(rules.headshot_kill_hitstop_ms, 0.0, 100.0)
	assert_gt(rules.max_hitstops_per_second, 0)
	assert_between(rules.headshot_kill_zoom_deg, 0.0, 4.0)
	assert_between(rules.downed_saturation, 0.0, 1.0)
	assert_between(rules.downed_vignette, 0.0, 1.0)
	assert_gt(rules.death_fade_s, 0.0)


func test_mantle_rules_match_the_design() -> void:
	var rules: MantleRules = load(FEEL_DIR.path_join("mantle_rules.tres")) as MantleRules
	assert_not_null(rules, "mantle_rules.tres is a MantleRules")
	assert_between(rules.min_height, 0.01, rules.max_height - 0.01, "0 < min_height < max_height")
	assert_eq(rules.max_height, 1.2, "game-design.md Movement: mantle up to 1.2 m")
	assert_gt(rules.reach, 0.0)
	assert_gt(rules.base_time, 0.0)
	assert_gt(rules.time_per_metre, 0.0)
	assert_lt(rules.duration(rules.max_height), 0.6, "the longest mantle is under 0.6 s")

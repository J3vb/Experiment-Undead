## Every field ability in content/abilities/ is complete and matches game-design.md "Field abilities".
extends GutTest

## Unlock level and cooldown from the design table, for the abilities built so far.
const DESIGN: Dictionary = {&"shock_pulse": [3, 60.0], &"med_burst": [8, 75.0], &"adrenal_rush": [22, 90.0]}


func test_every_ability_is_complete() -> void:
	var ids: Array[StringName] = Content.sorted_ids(&"abilities")
	assert_gt(ids.size(), 0, "at least Shock Pulse")
	var effects: Dictionary = {}
	var levels: Dictionary = {}
	for id: StringName in ids:
		var data: AbilityData = Content.get_item(&"abilities", id) as AbilityData
		assert_not_null(data, "%s is an AbilityData" % id)
		if data == null:
			continue
		assert_eq(data.id, id, "id matches the file name")
		assert_false(data.display_name.is_empty(), id)
		assert_false(data.description.is_empty(), id)
		assert_gt(data.cooldown, 0.0, id)
		assert_between(data.unlock_level, 1, 50, id)
		assert_not_null(data.icon, "%s has a HUD icon" % id)
		assert_not_null(data.sound, "%s has a sound" % id)
		assert_false(effects.has(data.effect), "%s: each effect is used by one ability" % id)
		effects[data.effect] = true
		assert_false(levels.has(data.unlock_level), "%s: one ability per unlock level" % id)
		levels[data.unlock_level] = true


func test_design_numbers() -> void:
	for id: StringName in DESIGN:
		var data: AbilityData = Content.get_item(&"abilities", id) as AbilityData
		assert_not_null(data, id)
		if data:
			assert_eq(data.unlock_level, DESIGN[id][0], "%s unlock level" % id)
			assert_eq(data.cooldown, DESIGN[id][1], "%s cooldown" % id)


func test_shock_pulse_numbers() -> void:
	var data: AbilityData = Content.get_item(&"abilities", &"shock_pulse") as AbilityData
	assert_eq(data.effect, AbilityData.Effect.SHOCK_PULSE)
	assert_eq(data.radius, 6.0, "within 6 m")
	assert_eq(data.duration, 2.0, "stuns for 2 s")
	assert_gt(data.amount, 0.0, "knocks back")


func test_med_burst_and_adrenal_rush_numbers() -> void:
	var med: AbilityData = Content.get_item(&"abilities", &"med_burst") as AbilityData
	assert_eq(med.effect, AbilityData.Effect.MED_BURST)
	assert_eq(med.amount, 50.0, "teammates heal 50")
	var rush: AbilityData = Content.get_item(&"abilities", &"adrenal_rush") as AbilityData
	assert_eq(rush.effect, AbilityData.Effect.ADRENAL_RUSH)
	assert_eq(rush.duration, 8.0)
	assert_eq(rush.amount, 0.3, "+30% move speed and fire rate")

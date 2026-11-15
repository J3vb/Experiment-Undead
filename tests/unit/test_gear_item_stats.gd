## Real gear affixes feed the existing runtime stat keys and reduction direction.
extends GutTest


func test_regen_delay_reduces_seconds_without_changing_the_saved_line_or_display_value() -> void:
	for tier: int in [1, 5]:
		for q: float in [0.0, 1.0]:
			var saved: Dictionary = {"uid": "vest", "aff": [["regen_delay", tier, q]]}
			var before: Dictionary = saved.duplicate(true)
			var seconds: float = ItemRoller.affix_value(&"regen_delay", tier, q)
			var item: ItemInstance = ItemInstance.new(saved)
			assert_gt(seconds, 0.0, "the displayed reduction is positive")
			assert_almost_eq(ItemInstance.stat_value(item.stats, &"regen_delay", 5.0), 5.0 - seconds, 0.00001)
			assert_eq(saved, before)
			assert_eq(item.data, before)
			assert_eq(ItemRoller.affix_value(&"regen_delay", tier, q), seconds)


func test_sprint_duration_increases_the_stamina_duration_stat() -> void:
	var gear: ItemInstance = ItemInstance.new({"aff": [["sprint_duration", 5, 1.0]]})
	assert_almost_eq(ItemInstance.stat_value(gear.stats, &"sprint_time", 4.0), 5.6, 0.00001)


func test_reload_focus_adds_to_the_gun_reload_speed_before_converting_to_time() -> void:
	var gear: ItemInstance = ItemInstance.new({"aff": [["reload_focus", 5, 1.0]]})
	var gun: ItemInstance = ItemInstance.new({"aff": [["reload_pct", 5, 1.0]]})
	assert_almost_eq(ItemInstance.stat_value(gear.stats, &"reload_time", 2.0, gun.stats), 2.0 / 1.3, 0.00001)


func test_headshot_focus_adds_to_the_gun_headshot_bonus() -> void:
	var gear: ItemInstance = ItemInstance.new({"aff": [["headshot_focus", 5, 1.0]]})
	var gun: ItemInstance = ItemInstance.new({"aff": [["hs_pct", 5, 1.0]]})
	assert_almost_eq(ItemInstance.stat_value(gear.stats, &"head_damage", 3.0, gun.stats), 3.0 * 1.42, 0.00001)


func test_all_damage_and_mule_apply_to_weapon_snapshots_and_add_to_gun_bonuses() -> void:
	var gear: ItemInstance = ItemInstance.new({"aff": [["all_damage", 5, 1.0], ["mule", 5, 1.0]]})
	var gun: ItemInstance = ItemInstance.new(
		{"rar": "common", "aff": [["dmg_pct", 5, 1.0]], "imp": ["deep_reserve", 1.0]}
	)
	var base: WeaponData = Content.weapon(&"pistol_service")
	var damage: float = base.damage
	var reserve: int = base.max_reserve
	var snapshot: WeaponData = gun.weapon_data(base, gear.stats)
	assert_almost_eq(snapshot.damage, base.damage * 1.21, 0.00001)
	assert_almost_eq(snapshot.min_damage, base.min_damage * 1.21, 0.00001)
	assert_eq(snapshot.starting_reserve, roundi(base.starting_reserve * 1.65))
	assert_eq(snapshot.max_reserve, roundi(base.max_reserve * 1.65))
	assert_eq(base.damage, damage)
	assert_eq(base.max_reserve, reserve)

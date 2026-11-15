## Locks the two double-barrels to the roster and preserves their fixed barrel
## capacity through Reforging, with distinct models, sounds and Vault entries.
extends GutTest

const SCALE: float = 0.57
## Sheet damage, pellets, rpm, reserve, reload, ADS, drop weight, cost, loot tags.
const SHEET: Dictionary = {
	&"coachman_2b": [38.0, 10, 200.0, 30, 2.6, 0.25, 100, 900, [&"shotgun", &"double"]],
	&"grubber_sawnoff": [30.0, 8, 240.0, 24, 2.2, 0.18, 80, 0, [&"shotgun", &"double", &"sidearm"]],
}


func test_double_barrels_match_the_roster() -> void:
	for id: StringName in SHEET:
		var row: Array = SHEET[id]
		var gun: WeaponData = Content.weapon(id)
		assert_not_null(gun, String(id) + " is indexed")
		if gun == null:
			continue
		assert_almost_eq(gun.damage, float(row[0]) * SCALE, 0.001, String(id) + " sheet damage x0.57")
		assert_lt(gun.min_damage, gun.damage, String(id) + " falls off")
		assert_eq(gun.pellets, row[1], String(id) + " pellets per barrel")
		assert_eq(gun.fire_mode, WeaponData.FireMode.SEMI, String(id) + " semi-auto")
		assert_eq(gun.rounds_per_minute, row[2], String(id) + " rpm")
		assert_eq(gun.magazine_size, 2, String(id) + " two barrels")
		assert_eq(gun.starting_reserve, row[3], String(id) + " reserve")
		assert_eq(gun.max_reserve, row[3], String(id) + " max reserve")
		assert_eq(gun.reload_time, row[4], String(id) + " reload")
		assert_eq(gun.empty_reload_time, row[4], String(id) + " both shells reload together")
		assert_eq(gun.ads_time, row[5], String(id) + " ADS")
		assert_eq(gun.move_speed_multiplier, 1.0, String(id) + " full movement")
		assert_almost_eq(gun.crate_weight, float(row[6]) / 100.0, 0.001, String(id) + " drop weight")
		assert_eq(gun.cost, row[7], String(id) + " wall cost")
		assert_eq(gun.loot_tags, Array(row[8], TYPE_STRING_NAME, &"", null), String(id) + " loot tags")


func test_reforged_double_barrels_keep_two_rounds() -> void:
	for id: StringName in SHEET:
		var gun: WeaponData = Content.weapon(id)
		var up: WeaponData = gun.upgraded
		assert_not_null(up, String(id) + " has Reforged")
		if up == null:
			continue
		assert_eq(up.id, StringName(String(id) + "_reforged"))
		assert_string_ends_with(up.display_name, " Reforged")
		assert_eq(up.magazine_size, 2, "Reforging cannot add a third barrel")
		assert_almost_eq(up.damage, gun.damage * 2.0, 0.001)
		assert_almost_eq(up.min_damage, gun.min_damage * 2.0, 0.001)
		assert_eq(up.max_reserve, gun.max_reserve * 2)
		assert_eq(up.pellets, gun.pellets)
		assert_eq(up.loot_tags, gun.loot_tags)
		assert_eq(up.viewmodel_scene, gun.viewmodel_scene)


func test_both_double_barrels_are_in_the_vault() -> void:
	var level: Node = (load("res://levels/halcyon_labs/map.tscn") as PackedScene).instantiate()
	var vault: SpecimenVault = level.find_child("SpecimenVault", true, false) as SpecimenVault
	assert_not_null(vault)
	if vault:
		for id: StringName in SHEET:
			assert_has(vault.pool, Content.weapon(id), String(id) + " can roll from the Vault")
	level.free()


func test_viewmodels_have_flash_and_break_action_parts() -> void:
	for id: StringName in SHEET:
		var vm: Node = Content.weapon(id).viewmodel_scene.instantiate()
		for part: String in ["Bolt", "Muzzle", "Trigger", "FlashLight", "FlashMesh"]:
			assert_not_null(vm.find_child(part, true, false), String(id) + " has " + part)
		assert_null(vm.find_child("Magazine", true, false), "break-action shells have no box magazine")
		vm.free()


func test_shots_have_their_own_sound_and_grubber_spreads_wider() -> void:
	var coachman: WeaponData = Content.weapon(&"coachman_2b")
	var grubber: WeaponData = Content.weapon(&"grubber_sawnoff")
	assert_not_null(coachman.fire_sound)
	assert_not_null(grubber.fire_sound)
	assert_ne(coachman.fire_sound, grubber.fire_sound)
	assert_ne(coachman.fire_sound, Content.weapon(&"brenner_trench").fire_sound)
	assert_gt(coachman.fire_sound.get_length(), grubber.fire_sound.get_length())
	assert_gt(grubber.hip_spread, coachman.hip_spread)
	assert_lt(grubber.falloff_end, coachman.falloff_end)

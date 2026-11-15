## Locks the five Vault guns (roster batch A1) to the balance sheet: sheet numbers
## with damage x 0.57, Reforged Tier I, loot tags from the roster and their viewmodels.
extends GutTest

const SCALE: float = 0.57
## id: [sheet damage, pellets, head mult, fire mode, rpm, mag, reserve, reload, ads, move, roster drop weight, tags]
const SHEET: Dictionary = {
	&"hollis_44":
	[180.0, 1, 2.5, WeaponData.FireMode.SEMI, 160.0, 6, 48, 2.8, 0.18, 1.0, 100, [&"pistol", &"revolver"]],
	&"mako_pdw": [55.0, 1, 2.5, WeaponData.FireMode.BURST, 1000.0, 40, 240, 2.2, 0.18, 1.0, 80, [&"smg", &"burst"]],
	&"atlas_auto": [30.0, 8, 2.5, WeaponData.FireMode.AUTO, 300.0, 10, 60, 2.8, 0.25, 0.95, 80, [&"shotgun", &"auto"]],
	&"halberd_lmg": [75.0, 1, 2.5, WeaponData.FireMode.AUTO, 600.0, 100, 400, 5.5, 0.35, 0.85, 60, [&"lmg"]],
	&"corvid_338":
	[600.0, 1, 4.0, WeaponData.FireMode.SEMI, 45.0, 5, 30, 3.2, 0.35, 0.9, 60, [&"rifle", &"sniper", &"bolt"]],
}


func test_vault_guns_match_the_balance_sheet() -> void:
	for id: StringName in SHEET:
		var row: Array = SHEET[id]
		var gun: WeaponData = Content.weapon(id)
		assert_not_null(gun, String(id) + " is in content/weapons")
		if gun == null:
			continue
		assert_almost_eq(gun.damage, float(row[0]) * SCALE, 0.001, String(id) + " damage is sheet x 0.57")
		assert_lt(gun.min_damage, gun.damage, String(id) + " falls off with range")
		assert_eq(gun.pellets, row[1], String(id) + " pellets")
		assert_eq(gun.head_multiplier, row[2], String(id) + " head multiplier")
		assert_eq(gun.fire_mode, row[3], String(id) + " fire mode")
		assert_eq(gun.rounds_per_minute, row[4], String(id) + " rpm")
		assert_eq(gun.magazine_size, row[5], String(id) + " magazine")
		assert_eq(gun.starting_reserve, row[6], String(id) + " reserve")
		assert_eq(gun.max_reserve, row[6], String(id) + " max reserve")
		assert_eq(gun.reload_time, row[7], String(id) + " reload")
		assert_eq(gun.ads_time, row[8], String(id) + " ADS time")
		assert_eq(gun.move_speed_multiplier, row[9], String(id) + " move speed")
		assert_almost_eq(gun.crate_weight, float(row[10]) / 100.0, 0.001, String(id) + " Vault weight = drop weight")
		assert_eq(gun.loot_tags, Array(row[11], TYPE_STRING_NAME, &"", null), String(id) + " roster loot tags")
		assert_eq(gun.cost, 0, String(id) + " has no wall price")


func test_vault_guns_reforge_into_tier_one() -> void:
	for id: StringName in SHEET:
		var gun: WeaponData = Content.weapon(id)
		var up: WeaponData = gun.upgraded
		assert_not_null(up, String(id) + " has a Reforged version")
		if up == null:
			continue
		assert_eq(up.id, StringName(String(id) + "_reforged"))
		assert_string_ends_with(up.display_name, " Reforged")
		assert_almost_eq(up.min_damage, gun.min_damage * 2.0, 0.001, String(id) + " Reforged min damage x2")
		assert_eq(up.viewmodel_scene, gun.viewmodel_scene, String(id) + " Reforged keeps the model")


func test_handling_fits_each_role() -> void:
	var revolver: WeaponData = Content.weapon(&"hollis_44")
	var pistol: WeaponData = Content.weapon(&"pistol_service")
	assert_gt(revolver.recoil.pattern[0].y, pistol.recoil.pattern[0].y, "Hollis kicks harder than the M-9")
	var mako: WeaponData = Content.weapon(&"mako_pdw")
	assert_eq(mako.burst_count, 3, "Mako fires three-round bursts")
	var atlas: WeaponData = Content.weapon(&"atlas_auto")
	assert_lte(atlas.max_range, Content.weapon(&"brenner_trench").max_range, "Atlas is a close-range shotgun")
	var halberd: WeaponData = Content.weapon(&"halberd_lmg")
	assert_gt(halberd.empty_reload_time, Content.weapon(&"rifle_ar").empty_reload_time, "LMG reloads slowest")
	var corvid: WeaponData = Content.weapon(&"corvid_338")
	assert_lt(corvid.ads_fov, Content.weapon(&"talon_dmr").ads_fov, "Corvid zooms further than the Talon")
	assert_gt(corvid.hip_spread, Content.weapon(&"talon_dmr").hip_spread, "no-scoping is a gamble")


func test_viewmodels_carry_the_parts_code_animates() -> void:
	for id: StringName in SHEET:
		var gun: WeaponData = Content.weapon(id)
		var vm: Node = gun.viewmodel_scene.instantiate()
		assert_not_null(vm.find_child("Bolt", true, false), String(id) + " has a Bolt to kick")
		assert_not_null(vm.find_child("FlashLight", true, false), String(id) + " has a muzzle flash light")
		var magazine: Node = vm.find_child("Magazine", true, false)
		if id == &"hollis_44":
			assert_null(magazine, "the revolver has no magazine to drop")
		else:
			assert_not_null(magazine, String(id) + " drops its magazine on reload")
		vm.free()
	var corvid: Node = Content.weapon(&"corvid_338").viewmodel_scene.instantiate()
	var lens: ScopeLens = corvid.find_child("ScopeLens", true, false) as ScopeLens
	assert_not_null(lens, "Corvid has a picture-in-picture scope")
	if lens:
		assert_gt(lens.zoom, 3.0, "Corvid scope zooms further than the Talon's 3x")
	corvid.free()


func test_fire_sounds_are_their_own() -> void:
	var seen: Array[AudioStream] = []
	for id: StringName in SHEET:
		var sound: AudioStream = Content.weapon(id).fire_sound
		assert_false(seen.has(sound), String(id) + " has its own shot sound")
		seen.append(sound)
	var corvid: float = Content.weapon(&"corvid_338").fire_sound.get_length()
	assert_gt(corvid, Content.weapon(&"talon_dmr").fire_sound.get_length(), "Corvid rings out longest")
	assert_lt(Content.weapon(&"mako_pdw").fire_sound.get_length(), 0.2, "Mako shot is short for bursts")

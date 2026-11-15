## Locks the piercing rifles to roster numbers, Tier I upgrades and their sources.
extends GutTest

const GUNS: Dictionary = {
	&"fieldhand_lever": [150.0, 140.0, 8, 64, 3.0, 0.25, 1.0, 1, 1.0, [&"rifle", &"lever"]],
	&"ironwood_50": [450.0, 80.0, 6, 36, 3.6, 0.4, 0.85, 2, 0.4, [&"rifle", &"sniper", &"anti_materiel"]],
}


func test_rifles_match_the_roster() -> void:
	for id: StringName in GUNS:
		var gun: WeaponData = Content.weapon(id)
		var row: Array = GUNS[id]
		assert_not_null(gun, String(id) + " is indexed")
		if gun == null:
			continue
		assert_almost_eq(gun.damage, float(row[0]) * 0.57, 0.001, String(id) + " sheet damage scaled once")
		assert_lt(gun.min_damage, gun.damage)
		assert_eq(gun.pellets, 1)
		assert_eq(gun.head_multiplier, 3.0)
		assert_eq(gun.fire_mode, WeaponData.FireMode.SEMI)
		assert_eq(gun.rounds_per_minute, row[1])
		assert_eq(gun.magazine_size, row[2])
		assert_eq(gun.starting_reserve, row[3])
		assert_eq(gun.max_reserve, row[3])
		assert_eq(gun.reload_time, row[4])
		assert_eq(gun.ads_time, row[5])
		assert_eq(gun.move_speed_multiplier, row[6])
		assert_eq(gun.pierce_count, row[7])
		assert_eq(gun.crate_weight, row[8])
		assert_eq(gun.loot_tags, Array(row[9], TYPE_STRING_NAME, &"", null))
		assert_eq(gun.cost, 0, String(id) + " has no current wall-buy")


func test_tier_one_preserves_the_mechanics_and_presentation() -> void:
	for id: StringName in GUNS:
		var gun: WeaponData = Content.weapon(id)
		var up: WeaponData = gun.upgraded
		assert_not_null(up)
		if up == null:
			continue
		assert_eq(up.id, StringName(String(id) + "_reforged"))
		assert_almost_eq(up.damage, gun.damage * 2.0, 0.001)
		assert_almost_eq(up.min_damage, gun.min_damage * 2.0, 0.001)
		assert_eq(up.magazine_size, int(gun.magazine_size * 1.5))
		assert_eq(up.max_reserve, gun.max_reserve * 2)
		assert_eq(up.pierce_count, gun.pierce_count)
		assert_eq(up.reload_per_round, gun.reload_per_round)
		assert_eq(up.per_round_time, gun.per_round_time)
		assert_eq(up.viewmodel_scene, gun.viewmodel_scene)
		assert_eq(up.fire_sound, gun.fire_sound)


func test_fieldhand_loads_rounds_and_brenner_keeps_its_existing_reload() -> void:
	var fieldhand: WeaponData = Content.weapon(&"fieldhand_lever")
	assert_true(fieldhand.reload_per_round)
	assert_eq(fieldhand.per_round_time, 0.375)
	assert_false(Content.weapon(&"ironwood_50").reload_per_round)
	assert_false(Content.weapon(&"brenner_trench").reload_per_round)
	assert_false(Content.weapon(&"brenner_trench_reforged").reload_per_round)


func test_fieldhand_enters_the_vault_and_ironwood_stays_loot_only() -> void:
	var map: Node = (load("res://levels/halcyon_labs/map.tscn") as PackedScene).instantiate()
	var vault: SpecimenVault = map.find_child("SpecimenVault", true, false) as SpecimenVault
	assert_has(vault.pool, Content.weapon(&"fieldhand_lever"))
	assert_does_not_have(vault.pool, Content.weapon(&"ironwood_50"))
	for wall: Node in map.find_children("*", "WallBuy", true, false):
		assert_false((wall as WallBuy).weapon.id in GUNS, "signature wall awaits Kessel Dam")
	map.free()


func test_ironwood_roster_keeps_its_rare_floor_and_level_25_unlock() -> void:
	var file: FileAccess = FileAccess.open("res://docs/design/balance/roster.csv", FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var found: bool = false
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row[0] != "ironwood_50":
			continue
		found = true
		assert_eq(row[6], "Loot")
		assert_eq(row[9], "25")
		assert_eq(row[11], "Rare")
		assert_eq(row[24], "C built")
	assert_true(found, "Ironwood remains in the roster")


func test_ironwood_uses_the_corvid_scope_and_rifles_have_separate_reports() -> void:
	var ironwood: WeaponData = Content.weapon(&"ironwood_50")
	var corvid: WeaponData = Content.weapon(&"corvid_338")
	var vm: Node = ironwood.viewmodel_scene.instantiate()
	var lens: ScopeLens = vm.find_child("ScopeLens", true, false) as ScopeLens
	assert_not_null(lens)
	if lens:
		assert_eq(lens.zoom, 4.0)
	assert_eq(ironwood.ads_fov, corvid.ads_fov)
	assert_ne(ironwood.fire_sound, corvid.fire_sound)
	var fieldhand: WeaponData = Content.weapon(&"fieldhand_lever")
	assert_ne(fieldhand.fire_sound, ironwood.fire_sound)
	assert_gt(ironwood.fire_sound.get_length(), fieldhand.fire_sound.get_length())
	vm.free()

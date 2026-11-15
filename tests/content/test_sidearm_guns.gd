## The Wren follows its roster row; the Warden keeps its existing prototype stats.
extends GutTest

const ROSTER: String = "res://docs/design/balance/roster.csv"
const WARDEN: Dictionary = {
	"cost": 0,
	"damage": 45.0,
	"min_damage": 25.0,
	"falloff_start": 15.0,
	"falloff_end": 40.0,
	"max_range": 200.0,
	"pellets": 1,
	"head_multiplier": 2.5,
	"limb_multiplier": 0.8,
	"fire_mode": WeaponData.FireMode.SEMI,
	"rounds_per_minute": 450.0,
	"burst_count": 3,
	"magazine_size": 12,
	"starting_reserve": 48,
	"max_reserve": 96,
	"reload_time": 1.5,
	"empty_reload_time": 1.8,
	"ads_time": 0.15,
	"ads_fov": 62.0,
	"sprint_to_fire_time": 0.18,
	"move_speed_multiplier": 1.05,
	"hip_spread": 1.8,
	"ads_spread": 0.2,
	"move_spread": 2.0,
	"spread_per_shot": 0.6,
	"max_spread": 5.0,
	"spread_recovery": 8.0,
	"viewmodel_kick": 0.06,
	"hip_position": Vector3(0.18, -0.17, -0.42),
	"ads_position": Vector3(0, -0.046, -0.3),
}


func _roster_row(id: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(ROSTER, FileAccess.READ)
	assert_not_null(file, "roster CSV is readable")
	if file == null:
		return {}
	var header: PackedStringArray = []
	while not file.eof_reached():
		var fields: PackedStringArray = file.get_csv_line()
		if not fields.is_empty() and fields[0] == "id":
			header = fields
		elif fields.size() == header.size() and not fields.is_empty() and fields[0] == id:
			var row: Dictionary = {}
			for index: int in header.size():
				row[header[index]] = fields[index]
			return row
	fail_test("roster contains " + id)
	return {}


func test_wren_matches_roster_numbers_and_sidearm_tags() -> void:
	var row: Dictionary = _roster_row("wren_mp")
	var gun: WeaponData = Content.weapon(&"wren_mp")
	assert_not_null(gun, "Wren is discovered as weapon content")
	if gun == null or row.is_empty():
		return
	assert_eq(gun.display_name, row["Name"])
	assert_eq(row["Slot"], "Sidearm")
	assert_eq(gun.fire_mode, WeaponData.FireMode.AUTO)
	assert_almost_eq(gun.damage, float(row["Damage / pellet"]) * 0.57, 0.001)
	assert_eq(gun.pellets, int(row["Pellets"]))
	assert_eq(gun.head_multiplier, 2.5, "blank override keeps the normal head multiplier")
	assert_eq(gun.rounds_per_minute, float(row["RPM"]))
	assert_eq(gun.magazine_size, int(row["Mag"]))
	assert_eq(gun.starting_reserve, int(row["Reserve"]))
	assert_eq(gun.max_reserve, int(row["Reserve"]))
	assert_eq(gun.reload_time, float(row["Reload s"]))
	assert_eq(gun.ads_time, float(row["ADS s"]))
	assert_eq(gun.move_speed_multiplier, float(row["Move mult"]))
	assert_almost_eq(gun.crate_weight, float(row["Drop weight"]) / 100.0, 0.001)
	var tags: Array[StringName] = []
	for tag: String in String(row["Loot tags"]).split(";"):
		tags.append(StringName(tag))
	assert_eq(gun.loot_tags, tags)
	assert_has(gun.loot_tags, &"pistol", "loot treats the Wren as a sidearm")
	assert_has(gun.loot_tags, &"machine_pistol", "machine-pistol affix exclusions apply")
	assert_lt(gun.min_damage, gun.damage, "close-range damage falls off")
	assert_almost_eq(gun.magazine_size * gun.get_fire_interval(), 1.2, 0.001, "20 rounds at 1000 rpm")


func test_wren_reforges_into_tier_one() -> void:
	var gun: WeaponData = Content.weapon(&"wren_mp")
	var upgraded: WeaponData = gun.upgraded
	assert_not_null(upgraded, "Wren links its Reforged resource")
	if upgraded == null:
		return
	assert_eq(upgraded, Content.weapon(&"wren_mp_reforged"))
	assert_eq(upgraded.display_name, "Wren MP Reforged")
	assert_eq(upgraded.damage, gun.damage * 2.0)
	assert_eq(upgraded.min_damage, gun.min_damage * 2.0)
	assert_eq(upgraded.magazine_size, int(gun.magazine_size * 1.5))
	assert_eq(upgraded.max_reserve, gun.max_reserve * 2)
	assert_eq(upgraded.starting_reserve, upgraded.max_reserve)
	assert_eq(upgraded.loot_tags, gun.loot_tags)
	assert_eq(upgraded.fire_mode, gun.fire_mode)
	assert_eq(upgraded.rounds_per_minute, gun.rounds_per_minute)
	assert_eq(upgraded.viewmodel_scene, gun.viewmodel_scene)
	assert_eq(upgraded.fire_sound, gun.fire_sound)
	assert_null(upgraded.upgraded, "only Tier I is built")


func test_warden_numbers_and_recoil_are_unchanged() -> void:
	for id: StringName in [&"pistol_service", &"pistol_service_reforged"]:
		var gun: WeaponData = Content.weapon(id)
		var expected: Dictionary = WARDEN.duplicate()
		if id == &"pistol_service_reforged":
			expected.merge(
				{"damage": 90.0, "min_damage": 50.0, "magazine_size": 18, "starting_reserve": 192, "max_reserve": 192},
				true
			)
		for field: String in expected:
			assert_eq(gun.get(field), expected[field], "%s keeps %s" % [id, field])
		assert_eq(gun.recoil.pattern, Array([Vector2(0, 2.2)], TYPE_VECTOR2, &"", null))
		assert_eq(gun.recoil.random_spread, Vector2(0.4, 0.3))
		assert_eq(gun.recoil.recovery_speed, 12.0)
		assert_eq(gun.recoil.ads_multiplier, 0.7)
		assert_eq(gun.recoil.permanent_ratio, 0.15)
		assert_eq(gun.recoil.reset_time, 0.25)
		assert_eq(gun.recoil.repeat_last, 1)
		assert_eq(gun.fire_sound.resource_path, "res://assets/audio/rifle_fire.wav")
		assert_eq(gun.viewmodel_scene.resource_path, "res://systems/weapons/viewmodels/pistol_viewmodel.tscn")


func test_wren_has_lighter_kestrel_recoil_and_its_own_short_shot() -> void:
	var gun: WeaponData = Content.weapon(&"wren_mp")
	var kestrel: WeaponData = Content.weapon(&"kestrel_smg")
	assert_not_null(gun.recoil)
	assert_gt(gun.recoil.pattern.size(), 1, "sustained spray has a recoil pattern")
	assert_lt(gun.recoil.pattern[0].y, kestrel.recoil.pattern[0].y)
	assert_lt(gun.viewmodel_kick, kestrel.viewmodel_kick)
	assert_lte(gun.recoil.random_spread.x, kestrel.recoil.random_spread.x)
	assert_not_null(gun.fire_sound)
	assert_ne(gun.fire_sound, kestrel.fire_sound)
	assert_ne(gun.fire_sound, Content.weapon(&"pistol_service").fire_sound)
	assert_gt(gun.fire_sound.get_length(), 0.02)
	assert_lt(gun.fire_sound.get_length(), 0.2, "short shot suits automatic fire")


func test_wren_is_in_the_vault_pool_without_a_wall_buy() -> void:
	var map: Node = (load("res://levels/halcyon_labs/map.tscn") as PackedScene).instantiate()
	var vault: SpecimenVault = map.find_child("SpecimenVault", true, false) as SpecimenVault
	var gun: WeaponData = Content.weapon(&"wren_mp")
	assert_not_null(vault)
	assert_has(vault.pool, gun, "Wren can roll before Grauwald exists")
	assert_eq(gun.cost, 0, "no provisional wall price")
	for node: Node in map.find_children("*", "WallBuy", true, false):
		assert_ne((node as WallBuy).weapon, gun, "Grauwald gets the wall buy with its map")
	map.free()

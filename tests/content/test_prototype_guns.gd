## Fixed Prototype weapons use roster stats and enter only the low-weight Vault pool.
extends GutTest

const SCALE: float = 0.57
## id: [sheet damage, fire mode, rpm, magazine, reserve, signature]
const SHEET: Dictionary = {
	&"cryo_lance": [120.0, WeaponData.FireMode.SEMI, 120.0, 8, 48, &"freeze_shatter"],
	&"synapse": [35.0, WeaponData.FireMode.AUTO, 600.0, 60, 180, &"fenlight_chain"],
}


func test_prototypes_match_roster_numbers() -> void:
	for id: StringName in SHEET:
		var gun: WeaponData = Content.weapon(id)
		var row: Array = SHEET[id]
		assert_not_null(gun, String(id) + " is indexed")
		if gun == null:
			continue
		assert_eq(gun.id, id)
		assert_almost_eq(gun.damage, float(row[0]) * SCALE, 0.001, String(id) + " damage is sheet x 0.57")
		assert_lt(gun.min_damage, gun.damage)
		assert_eq(gun.pellets, 1)
		assert_eq(gun.head_multiplier, 2.5)
		assert_eq(gun.fire_mode, row[1])
		assert_eq(gun.rounds_per_minute, row[2])
		assert_eq(gun.magazine_size, row[3])
		assert_eq(gun.starting_reserve, row[4])
		assert_eq(gun.max_reserve, row[4])
		assert_eq(gun.reload_time, 3.0)
		assert_eq(gun.ads_time, 0.25)
		assert_eq(gun.move_speed_multiplier, 1.0)
		assert_eq(gun.cost, 0, "no wall buy")


func test_prototypes_have_fixed_rarity_signature_and_ammo_line() -> void:
	for id: StringName in SHEET:
		var gun: WeaponData = Content.weapon(id)
		assert_eq(gun.loot_tags, Array([&"prototype"], TYPE_STRING_NAME, &"", null))
		assert_eq(gun.get_meta(&"rarity"), &"prototype")
		assert_eq(gun.get_meta(&"fixed_signature"), SHEET[id][5])
		assert_eq(gun.get_meta(&"fabricator"), 0.09)


func test_reforging_is_deterministic_and_preserves_the_fixed_prototype() -> void:
	for id: StringName in SHEET:
		var gun: WeaponData = Content.weapon(id)
		var reforged: WeaponData = gun.upgraded
		assert_not_null(reforged)
		if reforged == null:
			continue
		assert_eq(reforged.id, StringName(String(id) + "_reforged"))
		assert_almost_eq(reforged.damage, gun.damage * 2.0, 0.001)
		assert_almost_eq(reforged.min_damage, gun.min_damage * 2.0, 0.001)
		assert_eq(reforged.magazine_size, int(gun.magazine_size * 1.5))
		assert_eq(reforged.max_reserve, gun.max_reserve * 2)
		assert_eq(reforged.loot_tags, gun.loot_tags)
		assert_eq(reforged.get_meta(&"rarity"), &"prototype")
		assert_eq(reforged.get_meta(&"fixed_signature"), gun.get_meta(&"fixed_signature"))
		assert_eq(reforged.get_meta(&"fabricator"), 0.09)
		assert_eq(reforged.viewmodel_scene, gun.viewmodel_scene)
		assert_null(reforged.upgraded)


func test_vault_pool_contains_both_prototypes_at_low_weight() -> void:
	var map: Node = load("res://levels/halcyon_labs/map.tscn").instantiate()
	var vault: SpecimenVault = map.get_node("NavigationRegion3D/Machines/SpecimenVault") as SpecimenVault
	for id: StringName in SHEET:
		var gun: WeaponData = Content.weapon(id)
		assert_has(vault.pool, gun)
		assert_eq(gun.get_meta(&"rarity"), &"prototype", "Vault preserves fixed Prototype rarity")
		assert_almost_eq(gun.crate_weight, 0.02, 0.00001)
		for other: WeaponData in vault.pool:
			if not other.loot_tags.has(&"prototype"):
				assert_lt(gun.crate_weight, other.crate_weight)
	map.free()


func test_prototype_bases_are_never_randomly_rolled_at_any_rarity() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 419
	for id: StringName in SHEET:
		for rarity: StringName in ItemRoller.RARITIES:
			var state: int = rng.state
			assert_eq(ItemRoller.roll_weapon(rng, Content.weapon(id), rarity, 30), {})
			assert_push_error("Prototypes are fixed items")
			assert_eq(rng.state, state, "rejection never advances the loot RNG")


func test_prototypes_have_models_recoil_and_audio() -> void:
	for id: StringName in SHEET:
		var gun: WeaponData = Content.weapon(id)
		assert_not_null(gun.recoil)
		assert_false(gun.recoil.pattern.is_empty())
		assert_not_null(gun.fire_sound)
		assert_not_null(gun.dry_fire_sound)
		assert_not_null(gun.reload_sound)
		assert_eq(gun.viewmodel_scene.resource_path, "res://assets/models/weapons/%s.glb" % id)
		var model: Node = gun.viewmodel_scene.instantiate()
		for part: String in ["Bolt", "Magazine", "Trigger", "Muzzle"]:
			assert_not_null(model.find_child(part, true, false), String(id) + " has " + part)
		model.free()

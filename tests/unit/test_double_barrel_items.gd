## Loot and saved item modifiers cannot add barrels to the Coachman or Grubber.
## New rolls exclude magazine and fire-rate affixes; old saves retain their original data.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const DOUBLES: Array[StringName] = [
	&"coachman_2b", &"coachman_2b_reforged", &"grubber_sawnoff", &"grubber_sawnoff_reforged"
]


func _saved(id: StringName) -> Dictionary:
	return {
		"v": 1,
		"uid": "old_magazine_roll",
		"base": String(id),
		"rar": "legendary",
		"aff": [["mag_pct", 5, 1.0]],
		"craft": {"kept": [1, 2]},
	}


func test_saved_high_magazine_affixes_keep_two_barrels_without_mutation() -> void:
	for id: StringName in DOUBLES:
		var base: WeaponData = Content.weapon(id)
		var saved: Dictionary = _saved(id)
		var before: Dictionary = saved.duplicate(true)
		var item: ItemInstance = ItemInstance.new(saved)
		assert_almost_eq(item.value(&"mag_pct", 2.0), 2.6, 0.001, "the legacy affix is still decoded")
		var snapshot: WeaponData = item.weapon_data(base)
		assert_eq(snapshot.magazine_size, 2, String(id) + " cannot gain a third barrel")
		assert_ne(snapshot, base, "the equipped weapon uses its own snapshot")
		assert_eq(base.magazine_size, 2, "shared weapon content stays unchanged")
		assert_same(Content.weapon(id), base)
		assert_eq(saved, before, "loading a weapon never rewrites the saved item")
		assert_eq(item.data, before, "the in-memory item keeps its saved affix")


func test_extra_equipment_magazine_stats_cannot_expand_double_barrels() -> void:
	var extra: StatBlock = StatBlock.new()
	extra.add_modifier(&"mag_pct", "increased", 1.0, &"gear_magazine")
	extra.add_modifier(&"mag_pct", "flat", 5.0, &"gear_magazine")
	for id: StringName in DOUBLES:
		var saved: Dictionary = _saved(id)
		var before: Dictionary = saved.duplicate(true)
		var item: ItemInstance = ItemInstance.new(saved)
		var base: WeaponData = Content.weapon(id)
		var snapshot: WeaponData = item.weapon_data(base, extra)
		assert_eq(snapshot.magazine_size, 2, String(id) + " capacity stays fixed with item and gear bonuses")
		assert_eq((WeaponInstance.new(snapshot)).ammo_in_mag, 2, "the live gun starts with two shells")
		assert_eq(base.magazine_size, 2)
		assert_eq(item.data, before)
	assert_eq(extra.modifiers.size(), 2, "snapshotting does not consume equipment modifiers")


func test_seeded_loot_excludes_magazine_and_fire_rate_on_double_barrels() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 73021
	for affix_id: StringName in [&"mag_pct", &"fire_rate_pct"]:
		var affix: AffixData = Content.get_item(&"loot", affix_id) as AffixData
		assert_has(affix.blocked_tags, &"double", String(affix_id) + " is excluded by the roster")
	for id: StringName in DOUBLES:
		var blocked_rolls: Dictionary[String, int] = {"mag_pct": 0, "fire_rate_pct": 0}
		var other_lines: int = 0
		for rarity: StringName in [&"uncommon", &"rare", &"epic", &"legendary"]:
			for sample: int in 32:
				var rolled: Dictionary = ItemRoller.roll_weapon(rng, Content.weapon(id), rarity, 30)
				for line: Array in rolled.aff:
					if blocked_rolls.has(line[0]):
						blocked_rolls[line[0]] += 1
					else:
						other_lines += 1
		assert_eq(blocked_rolls["mag_pct"], 0, String(id) + " never rolls magazine capacity")
		assert_eq(blocked_rolls["fire_rate_pct"], 0, String(id) + " never rolls fire rate")
		assert_gt(other_lines, 0, "eligible loot affixes still roll")


func test_ordinary_rifle_still_receives_item_and_equipment_magazine_bonuses() -> void:
	var base: WeaponData = Content.weapon(&"rifle_ar")
	var original_magazine: int = base.magazine_size
	var item: ItemInstance = ItemInstance.new(_saved(base.id))
	assert_eq(item.weapon_data(base).magazine_size, roundi(original_magazine * 1.3))
	var extra: StatBlock = StatBlock.new()
	extra.add_modifier(&"mag_pct", "increased", 0.2, &"gear_magazine")
	assert_eq(item.weapon_data(base, extra).magazine_size, roundi(original_magazine * 1.5))
	assert_eq(base.magazine_size, original_magazine)


func test_saved_grubber_magazine_roll_equips_as_a_two_shell_sidearm() -> void:
	var player: Player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.input_enabled = false
	player.weapons.give(Content.weapon(&"pistol_service"))
	var primary: Weapon = player.weapons.give(Content.weapon(&"rifle_ar"))
	var saved: Dictionary = _saved(&"grubber_sawnoff")
	var before: Dictionary = saved.duplicate(true)
	ItemLoadout.apply(player, {"sidearm": saved})
	assert_eq(player.weapons.weapons.size(), 2)
	var grubber: Weapon = player.weapons.weapons[0]
	assert_eq(grubber.data.id, &"grubber_sawnoff")
	assert_eq(grubber.data.magazine_size, 2, "the saved magazine affix cannot add a barrel at spawn")
	assert_eq(grubber.instance.ammo_in_mag, 2)
	assert_eq(player.weapons.weapons[1], primary)
	assert_eq(saved, before)
	assert_eq(grubber.item.data, before)


func test_automatic_rifles_can_still_roll_fire_rate_affixes() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 73021
	var rifle: WeaponData = Content.weapon(&"rifle_ar")
	assert_eq(rifle.fire_mode, WeaponData.FireMode.AUTO)
	var seen: Array[String] = []
	for sample: int in 128:
		var rolled: Dictionary = ItemRoller.roll_weapon(rng, rifle, &"legendary", 30)
		for line: Array in rolled.aff:
			seen.append(line[0])
	assert_has(seen, "fire_rate_pct", "the exclusion applies only to the intended weapon tags")

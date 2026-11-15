## Character unlocks and rarity floors gate weapon rolls without advancing rejected loot RNG.
extends GutTest

const BASTIONS: Array[StringName] = [&"bastion_lmg", &"bastion_lmg_reforged"]

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 73021


func _assert_rejected(weapon: WeaponData, rarity: StringName, item_level: int, player_level: int = 1) -> void:
	var before: int = rng.state
	assert_eq(ItemRoller.roll_weapon(rng, weapon, rarity, item_level, player_level), {})
	assert_eq(rng.state, before, "ineligible rolls consume no randomness")


func _metadata(weapon: WeaponData) -> Dictionary:
	var snapshot: Dictionary = {}
	for key: StringName in weapon.get_meta_list():
		snapshot[key] = weapon.get_meta(key)
	return snapshot


func test_character_level_unlock_is_independent_of_item_level() -> void:
	for id: StringName in BASTIONS:
		var weapon: WeaponData = Content.weapon(id)
		_assert_rejected(weapon, &"rare", 50, 19)
		var item: Dictionary = ItemRoller.roll_weapon(rng, weapon, &"rare", 1, 20)
		assert_false(item.is_empty(), String(id) + " unlocks at character level 20 even in round one")
		if not item.is_empty():
			assert_eq(item.base, String(id))
			assert_eq(item.ilvl, 1, "character level does not replace the item's round level")
			assert_eq(item.rar, "rare")


func test_bastion_accepts_rare_epic_and_legendary_at_unlock() -> void:
	for id: StringName in BASTIONS:
		for rarity: StringName in [&"rare", &"epic", &"legendary"]:
			var item: Dictionary = ItemRoller.roll_weapon(rng, Content.weapon(id), rarity, 30, 20)
			assert_false(item.is_empty(), "%s accepts %s at character level 20" % [id, rarity])
			if not item.is_empty():
				assert_eq(item.rar, String(rarity))
				assert_eq(item.base, String(id))


func test_bastion_rejects_common_and_uncommon_even_at_max_character_level() -> void:
	for id: StringName in BASTIONS:
		for rarity: StringName in [&"common", &"uncommon"]:
			_assert_rejected(Content.weapon(id), rarity, 50, 50)


func test_four_argument_roll_cannot_use_item_level_to_bypass_unlock() -> void:
	for id: StringName in BASTIONS:
		var before: int = rng.state
		assert_eq(ItemRoller.roll_weapon(rng, Content.weapon(id), &"rare", 50), {})
		assert_eq(rng.state, before)


func test_rejected_rolls_leave_content_metadata_and_next_eligible_roll_unchanged() -> void:
	for id: StringName in BASTIONS:
		var weapon: WeaponData = Content.weapon(id)
		var metadata: Dictionary = _metadata(weapon)
		var damage: float = weapon.damage
		var other: RandomNumberGenerator = RandomNumberGenerator.new()
		other.seed = rng.seed
		other.state = rng.state
		_assert_rejected(weapon, &"rare", 50, 19)
		_assert_rejected(weapon, &"uncommon", 1, 50)
		var item: Dictionary = ItemRoller.roll_weapon(rng, weapon, &"epic", 30, 20)
		assert_eq(item, ItemRoller.roll_weapon(other, weapon, &"epic", 30, 20))
		assert_eq(rng.state, other.state)
		assert_eq(_metadata(weapon), metadata, "eligibility does not change the loaded WeaponData")
		assert_eq(weapon.damage, damage)


func test_metadata_free_weapons_keep_four_argument_seeded_rolls() -> void:
	var weapon: WeaponData = Content.weapon(&"rifle_ar")
	assert_false(weapon.has_meta(&"unlock_level"))
	assert_false(weapon.has_meta(&"min_rarity"))
	var other: RandomNumberGenerator = RandomNumberGenerator.new()
	other.seed = rng.seed
	for rarity: StringName in [&"common", &"uncommon", &"rare", &"epic", &"legendary"]:
		var item: Dictionary = ItemRoller.roll_weapon(rng, weapon, rarity, 1)
		assert_false(item.is_empty())
		assert_eq(item, ItemRoller.roll_weapon(other, weapon, rarity, 1, 1))
		assert_eq(rng.state, other.state)


func test_unknown_rarity_is_rejected_before_rng_or_content_lookup() -> void:
	_assert_rejected(Content.weapon(&"bastion_lmg"), &"unknown_rarity", 30, 50)
	_assert_rejected(Content.weapon(&"rifle_ar"), &"unknown_rarity", 30, 1)

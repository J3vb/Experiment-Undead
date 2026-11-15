## Fixed stash capacity, acquisition order and lossless equipment moves for weapon and gear slots.
extends GutTest

const PROFILE_ID: StringName = &"test_inventory_acquisition_order"
const PROFILE_PATH: String = "user://characters/test_inventory_acquisition_order.json"


func after_each() -> void:
	Content.reload()
	for path: String in [PROFILE_PATH, PROFILE_PATH + ".tmp", PROFILE_PATH + ".v0.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_add_until_full_then_refuse_without_changes() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	for slot: int in range(60):
		var item: Dictionary = _item("rifle_ar", str(slot))
		assert_eq(Inventory.add_to_stash(profile, item), slot)
		var expected: Dictionary = item.duplicate(true)
		expected["acquired"] = slot + 1
		assert_eq(profile.stash[slot], expected)
		assert_false(item.has("acquired"), "Acquisition metadata belongs to the stored copy")
	var before: Dictionary = profile.to_dict()
	var overflow: Dictionary = _item("pistol_service", "overflow")
	var original: Dictionary = overflow.duplicate(true)
	assert_eq(Inventory.add_to_stash(profile, overflow), -1)
	assert_eq(overflow, original)
	assert_eq(profile.to_dict(), before)
	assert_eq(profile.stash.size(), 60)


func test_empty_item_is_refused_without_changes() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	var before: Dictionary = profile.to_dict()
	assert_eq(Inventory.add_to_stash(profile, {}), -1)
	assert_eq(profile.to_dict(), before)


func test_added_item_is_independent_of_callers_dictionary() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	var item: Dictionary = _item("rifle_ar", "stored")
	item["future"] = {"nested": [1, null, {"retired_affix": true}]}
	var expected: Dictionary = item.duplicate(true)
	assert_eq(Inventory.add_to_stash(profile, item), 0)
	assert_eq(item, expected, "Adding never changes the caller's item")
	expected["acquired"] = 1
	item["uid"] = "changed"
	item["aff"][0][2] = 0.0
	item["future"]["nested"][2]["retired_affix"] = false
	assert_eq(profile.stash[0], expected)


func test_remove_keeps_slot_positions_and_add_reuses_first_gap() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	var first: Dictionary = _item("rifle_ar", "first")
	var last: Dictionary = _item("pistol_service", "last")
	profile.stash[0] = first
	profile.stash[1] = _item("rifle_ar", "removed")
	profile.stash[2] = last
	Inventory.remove(profile, 1)
	assert_eq(profile.stash.size(), 60)
	assert_eq(profile.stash[0], first)
	assert_eq(profile.stash[1], {})
	assert_eq(profile.stash[2], last)
	var replacement: Dictionary = _item("rifle_ar", "replacement")
	assert_eq(Inventory.add_to_stash(profile, replacement), 1)
	var expected: Dictionary = replacement.duplicate(true)
	expected["acquired"] = 3
	assert_eq(profile.stash[1], expected)
	assert_false(replacement.has("acquired"))


func test_equip_into_empty_slot_empties_only_source_stash_slot() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	var item: Dictionary = _item("rifle_ar", "primary")
	profile.stash[59] = item
	assert_true(Inventory.equip(profile, 59))
	assert_eq(profile.loadout[&"primary"], item)
	assert_eq(profile.stash[59], {})
	assert_eq(profile.stash.size(), 60)
	assert_eq(profile.loadout[&"sidearm"], {})
	assert_eq(profile.loadout[&"vest"], {})
	assert_eq(profile.loadout[&"charm"], {})
	assert_eq(profile.loadout[&"implant"], {})


func test_equip_swaps_in_place_even_with_full_stash() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	for slot: int in range(60):
		profile.stash[slot] = _item("rifle_ar", str(slot))
	var equipped: Dictionary = _item("rifle_ar", "equipped")
	equipped["future"] = {"nested": [1, null, {"retired_affix": true}]}
	profile.loadout[&"primary"] = equipped
	profile.loadout[&"sidearm"] = _item("pistol_service", "sidearm")
	var expected_stash: Array[Dictionary] = profile.stash.duplicate(true)
	var replacement: Dictionary = profile.stash[23]
	expected_stash[23] = equipped
	var sidearm: Dictionary = profile.loadout[&"sidearm"].duplicate(true)
	assert_true(Inventory.equip(profile, 23))
	assert_eq(profile.stash, expected_stash)
	assert_eq(profile.loadout[&"primary"], replacement)
	assert_eq(profile.loadout[&"sidearm"], sidearm)


func test_sidearm_equips_without_replacing_primary() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	var primary: Dictionary = _item("rifle_ar", "primary")
	var sidearm: Dictionary = _item("pistol_service", "sidearm")
	profile.loadout[&"primary"] = primary
	profile.stash[0] = sidearm
	assert_true(Inventory.equip(profile, 0))
	assert_eq(profile.loadout[&"sidearm"], sidearm)
	assert_eq(profile.loadout[&"primary"], primary)
	assert_eq(profile.stash[0], {})


func test_unequip_uses_first_empty_stash_slot() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	var stored: Dictionary = _item("rifle_ar", "stored")
	var equipped: Dictionary = _item("pistol_service", "equipped")
	profile.stash[0] = stored
	profile.loadout[&"sidearm"] = equipped
	assert_true(Inventory.unequip(profile, &"sidearm"))
	assert_eq(profile.stash[0], stored)
	assert_eq(profile.stash[1], equipped)
	assert_eq(profile.loadout[&"sidearm"], {})
	assert_eq(profile.stash.size(), 60)


func test_unequip_full_stash_refuses_without_changing_anything() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	for slot: int in range(60):
		profile.stash[slot] = _item("rifle_ar", str(slot))
	profile.loadout[&"primary"] = _item("rifle_ar", "equipped")
	var before: Dictionary = profile.to_dict()
	assert_false(Inventory.unequip(profile, &"primary"))
	assert_eq(profile.to_dict(), before)


func test_empty_and_invalid_slots_leave_profile_unchanged() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	profile.stash[0] = _item("rifle_ar", "stored")
	var before: Dictionary = profile.to_dict()
	assert_false(Inventory.equip(profile, 1))
	assert_false(Inventory.equip(profile, -1))
	assert_false(Inventory.equip(profile, 60))
	assert_false(Inventory.unequip(profile, &"primary"))
	assert_false(Inventory.unequip(profile, &"unknown"))
	Inventory.remove(profile, -1)
	Inventory.remove(profile, 60)
	assert_eq(profile.to_dict(), before)


func test_slot_for_maps_primary_and_sidearm_bases() -> void:
	for base: String in [
		"pistol_service", "pistol_service_reforged", "hollis_44", "hollis_44_reforged", "wren_mp", "wren_mp_reforged"
	]:
		assert_eq(Inventory.slot_for(_item(base, "sidearm")), &"sidearm", base)
	for base: String in [
		"rifle_ar",
		"rifle_ar_reforged",
		"kestrel_smg",
		"mako_pdw",
		"brenner_trench",
		"atlas_auto",
		"talon_dmr",
		"halberd_lmg",
		"corvid_338",
		"fieldhand_lever",
		"fieldhand_lever_reforged",
		"ironwood_50",
		"ironwood_50_reforged",
		"siphon",
	]:
		assert_eq(Inventory.slot_for(_item(base, "primary")), &"primary", base)


func test_weapon_slot_is_independent_of_affix_tags() -> void:
	Content._by_type[&"weapons"][&"test_sidearm_shotgun"] = "res://tests/fixtures/weapons/sidearm_shotgun.tres"
	Content._by_type[&"weapons"][&"test_primary_pistol"] = "res://tests/fixtures/weapons/primary_pistol.tres"
	assert_eq(Inventory.slot_for(_item("test_sidearm_shotgun", "sidearm")), &"sidearm")
	assert_eq(Inventory.slot_for(_item("test_primary_pistol", "primary")), &"primary")


func test_every_rolled_gear_base_adds_equips_swaps_and_unequips_losslessly() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42711
	var checked: int = 0
	for id: StringName in Content.ids(&"loot"):
		var base: GearBaseData = Content.get_item(&"loot", id) as GearBaseData
		if base == null:
			continue
		checked += 1
		var profile: CharacterProfile = CharacterProfile.new()
		profile.loadout[&"primary"] = _item("rifle_ar", "primary")
		profile.loadout[&"sidearm"] = _item("pistol_service", "sidearm")
		for other_id: StringName in [&"vest_heavy", &"charm_coin", &"implant_relay"]:
			var other_base: GearBaseData = Content.get_item(&"loot", other_id) as GearBaseData
			profile.loadout[other_base.slot] = ItemRoller.roll_gear(rng, other_base, &"epic", 30)
		profile.loadout[base.slot] = {}
		var expected_loadout: Dictionary = profile.loadout.duplicate(true)
		var first: Dictionary = ItemRoller.roll_gear(rng, base, &"rare", 30)
		first["future"] = {"nested": [null, {"retired_affix": true}]}
		first["craft"] = {"locked": [0], "unknown_rule": 3}
		var second: Dictionary = ItemRoller.roll_gear(rng, base, &"legendary", 50)
		assert_eq(Inventory.add_to_stash(profile, first), 0, String(id))
		assert_true(Inventory.equip(profile, 0), String(id))
		expected_loadout[base.slot] = first
		assert_eq(profile.loadout, expected_loadout, "only the gear slot changes")
		assert_eq(profile.stash[0], {})
		assert_eq(Inventory.add_to_stash(profile, second), 0, String(id))
		assert_true(Inventory.equip(profile, 0), String(id))
		expected_loadout[base.slot] = second
		assert_eq(profile.loadout, expected_loadout)
		assert_eq(profile.stash[0], first, "swapping preserves every previous item field")
		assert_true(Inventory.unequip(profile, StringName(base.slot)), String(id))
		expected_loadout[base.slot] = {}
		assert_eq(profile.loadout, expected_loadout)
		assert_eq(profile.stash[0], first)
		assert_eq(profile.stash[1], second, "unequipping preserves the rolled item")
		assert_eq(profile.stash.size(), 60)
	assert_eq(checked, 13)


func test_unknown_or_missing_base_cannot_equip_or_change_profile() -> void:
	for item: Dictionary in [{}, {"uid": "missing_base"}, _item("missing_weapon", "unknown"), {"base": "missing_gear"}]:
		var profile: CharacterProfile = CharacterProfile.new()
		profile.stash[0] = item
		profile.loadout[&"primary"] = _item("rifle_ar", "equipped")
		var before: Dictionary = profile.to_dict()
		assert_eq(Inventory.slot_for(item), &"")
		assert_false(Inventory.equip(profile, 0))
		assert_eq(profile.to_dict(), before)


func test_new_item_in_first_gap_is_newer_than_a_legacy_item_at_slot_nine() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	profile.stash[9] = _item("rifle_ar", "older")
	var item: Dictionary = _item("pistol_service", "newer")
	assert_eq(Inventory.add_to_stash(profile, item), 0)
	assert_eq(profile.stash[0]["acquired"], 10)
	assert_gt(int(profile.stash[0]["acquired"]), 9)
	assert_false(item.has("acquired"))


func test_equipped_newest_item_still_advances_the_next_acquisition_order() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	var newest: Dictionary = _item("rifle_ar", "newest")
	newest["acquired"] = 100
	profile.stash[9] = newest
	assert_true(Inventory.equip(profile, 9))
	assert_eq(Inventory.add_to_stash(profile, _item("pistol_service", "next")), 0)
	assert_eq(profile.stash[0]["acquired"], 101)
	assert_eq(profile.loadout[&"primary"]["acquired"], 100)


func test_adding_an_item_with_existing_order_preserves_age_and_nested_fields() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	var item: Dictionary = _item("rifle_ar", "returning")
	item["acquired"] = 7
	item["future"] = {"nested": [null, {"retired_affix": true}]}
	var expected: Dictionary = item.duplicate(true)
	assert_eq(Inventory.add_to_stash(profile, item), 0)
	assert_eq(profile.stash[0], expected)
	assert_eq(item, expected)


func test_unequip_preserves_both_recorded_age_and_legacy_missing_age() -> void:
	for recorded_age: bool in [false, true]:
		var profile: CharacterProfile = CharacterProfile.new()
		var item: Dictionary = _item("rifle_ar", "equipped")
		if recorded_age:
			item["acquired"] = 42
		item["future"] = {"nested": [1, null, {"retired_affix": true}]}
		profile.loadout[&"primary"] = item
		var expected: Dictionary = item.duplicate(true)
		assert_true(Inventory.unequip(profile, &"primary"))
		assert_eq(profile.stash[0], expected)
		assert_eq(item, expected)
		assert_eq(profile.stash[0].has("acquired"), recorded_age)


func test_profile_save_load_preserves_acquisition_order_and_nested_fields() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	profile.id = PROFILE_ID
	var item: Dictionary = _item("rifle_ar", "stored")
	item["future"] = {"nested": [1.25, null, {"retired_affix": true}]}
	assert_eq(Inventory.add_to_stash(profile, item), 0)
	assert_eq(Inventory.add_to_stash(profile, _item("pistol_service", "equipped")), 1)
	assert_true(Inventory.equip(profile, 1))
	assert_eq(profile.save(), OK)
	var restored: CharacterProfile = CharacterProfile.load_or_create(PROFILE_ID)
	assert_eq(int(restored.stash[0]["acquired"]), 1)
	assert_eq(int(restored.loadout[&"sidearm"]["acquired"]), 2)
	assert_eq(restored.stash[0]["future"], item["future"])
	assert_eq(Inventory.add_to_stash(restored, _item("rifle_ar", "later")), 1)
	assert_eq(restored.stash[1]["acquired"], 3)


func test_all_gear_slots_equip_and_unequip_through_inventory() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	for slot: StringName in [&"vest", &"charm", &"implant"]:
		var base: String = {&"vest": "vest_light", &"charm": "charm_dog_tags", &"implant": "implant_reflex"}[slot]
		assert_eq(Inventory.add_to_stash(profile, _item(base, String(slot))), 0)
		var expected: Dictionary = profile.stash[0].duplicate(true)
		assert_eq(Inventory.slot_for(expected), slot)
		assert_true(Inventory.equip(profile, 0))
		assert_eq(profile.loadout[slot], expected)
		assert_true(Inventory.unequip(profile, slot))
		assert_eq(profile.stash[0], expected)
		Inventory.remove(profile, 0)


func _item(base: String, uid: String) -> Dictionary:
	return {
		"v": 1,
		"uid": uid,
		"base": base,
		"rar": "rare",
		"ilvl": 15,
		"aff": [["dmg_pct", 3, 0.5], ["reload_pct", 2, 0.75]],
		"imp": ["reclaimer", 0.25],
		"trait": null,
		"set": null,
		"craft": {},
	}

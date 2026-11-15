## Fixed stash capacity, lossless equipment moves and weapon slot lookup.
extends GutTest


func after_each() -> void:
	Content.reload()


func test_add_until_full_then_refuse_without_changes() -> void:
	var profile: CharacterProfile = CharacterProfile.new()
	for slot: int in range(60):
		var item: Dictionary = _item("rifle_ar", str(slot))
		assert_eq(Inventory.add_to_stash(profile, item), slot)
		assert_eq(profile.stash[slot], item)
	var before: Dictionary = profile.to_dict()
	assert_eq(Inventory.add_to_stash(profile, _item("pistol_service", "overflow")), -1)
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
	assert_eq(profile.stash[1], replacement)


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
	for base: String in ["pistol_service", "pistol_service_reforged", "hollis_44", "hollis_44_reforged"]:
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
	]:
		assert_eq(Inventory.slot_for(_item(base, "primary")), &"primary", base)


func test_weapon_slot_is_independent_of_affix_tags() -> void:
	Content._by_type[&"weapons"][&"test_sidearm_shotgun"] = "res://tests/fixtures/weapons/sidearm_shotgun.tres"
	Content._by_type[&"weapons"][&"test_primary_pistol"] = "res://tests/fixtures/weapons/primary_pistol.tres"
	assert_eq(Inventory.slot_for(_item("test_sidearm_shotgun", "sidearm")), &"sidearm")
	assert_eq(Inventory.slot_for(_item("test_primary_pistol", "primary")), &"primary")


func test_unknown_or_missing_base_cannot_equip_or_change_profile() -> void:
	for item: Dictionary in [{}, {"uid": "missing_base"}, _item("missing_weapon", "unknown"), {"base": "vest_light"}]:
		var profile: CharacterProfile = CharacterProfile.new()
		profile.stash[0] = item
		profile.loadout[&"primary"] = _item("rifle_ar", "equipped")
		var before: Dictionary = profile.to_dict()
		assert_eq(Inventory.slot_for(item), &"")
		assert_false(Inventory.equip(profile, 0))
		assert_eq(profile.to_dict(), before)


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

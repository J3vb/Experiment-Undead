## Acquisition order survives fixed-slot reuse, equipment moves and profile saves.
extends GutTest

const PROFILE_ID: StringName = &"test_inventory_acquisition_order"
const PROFILE_PATH: String = "user://characters/test_inventory_acquisition_order.json"


func after_each() -> void:
	for path: String in [PROFILE_PATH, PROFILE_PATH + ".tmp", PROFILE_PATH + ".v0.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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

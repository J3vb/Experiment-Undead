## Equipped appearance uses each base's visual and real rarity, without changing item state.
extends GutTest


func test_each_filled_slot_uses_its_base_visual_real_rarity_and_default_dyes() -> void:
	var loadout: Dictionary = {
		"vest": {"base": "vest_heavy", "rar": "rare"},
		"charm": {"base": "charm_dog_tags", "rar": "epic"},
		"implant": {"base": "implant_reflex", "rar": "legendary"},
	}
	var look: CharacterLook = LookBuilder.from_equipped(loadout)
	assert_eq(look.slots.size(), 3)
	for slot: StringName in CharacterLook.SLOTS:
		assert_eq(look.slots[slot].visual_id, StringName(loadout[slot].base))
		assert_eq(look.slots[slot].rarity, StringName(loadout[slot].rar))
		assert_eq(look.slots[slot].dyes, [Color("5f6d68"), Color("2f393b")])
	assert_eq(look.set_counts.size(), 0)


func test_all_vest_frames_and_all_real_rarities_are_preserved() -> void:
	for base_id: StringName in [&"vest_light", &"vest_medium", &"vest_heavy"]:
		for rarity: StringName in [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"prototype"]:
			var look: CharacterLook = LookBuilder.from_equipped({&"vest": {"base": base_id, "rar": rarity}})
			assert_eq(look.slots[&"vest"].visual_id, base_id)
			assert_eq(look.slots[&"vest"].rarity, rarity)


func test_all_charm_and_implant_variants_keep_their_visual_and_real_rarity() -> void:
	var variants: Dictionary = {
		&"charm": [&"charm_dog_tags", &"charm_vial", &"charm_keycard", &"charm_dosimeter", &"charm_coin"],
		&"implant": [&"implant_reflex", &"implant_lung", &"implant_spine", &"implant_ocular", &"implant_relay"],
	}
	for slot: StringName in variants:
		for base_id: StringName in variants[slot]:
			for rarity: StringName in [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"prototype"]:
				var look: CharacterLook = LookBuilder.from_equipped({slot: {"base": base_id, "rar": rarity}})
				assert_eq(look.slots[slot].visual_id, base_id)
				assert_eq(look.slots[slot].rarity, rarity)


func test_missing_null_and_empty_slots_stay_empty() -> void:
	assert_eq(LookBuilder.from_equipped({}).slots.size(), 0)
	var look: CharacterLook = LookBuilder.from_equipped({"vest": {}, "charm": null, "implant": {}})
	assert_eq(look.slots.size(), 0)
	assert_eq(look.set_counts.size(), 0)
	look = LookBuilder.from_equipped({"charm": {"base": "charm_dog_tags", "rar": "rare"}})
	assert_eq(look.slots.keys(), [&"charm"])


func test_unknown_base_falls_back_to_that_slots_base_mesh_in_common() -> void:
	var look: CharacterLook = (
		LookBuilder
		. from_equipped(
			{
				"vest": {"base": "future_vest", "rar": "legendary"},
				"charm": {"base": "future_charm", "rar": "epic"},
				"implant": {"base": "future_implant", "rar": "prototype"},
			}
		)
	)
	var defaults: Dictionary = {&"vest": &"vest_medium", &"charm": &"charm_dog_tags", &"implant": &"implant_reflex"}
	for slot: StringName in CharacterLook.SLOTS:
		assert_eq(look.slots[slot].visual_id, defaults[slot])
		assert_eq(look.slots[slot].rarity, &"common")


func test_base_for_another_slot_falls_back_to_common() -> void:
	var look: CharacterLook = LookBuilder.from_equipped({"vest": {"base": "charm_dog_tags", "rar": "legendary"}})
	assert_eq(look.slots[&"vest"].visual_id, &"vest_medium")
	assert_eq(look.slots[&"vest"].rarity, &"common")


func test_set_counts_include_both_guns_and_keep_different_sets_separate() -> void:
	var loadout: Dictionary = {
		"primary": {"base": "rifle_ar", "rar": "legendary", "set": "lab"},
		"sidearm": {"base": "pistol_service", "rar": "legendary", "set": "lab"},
		"vest": {"base": "vest_medium", "rar": "legendary", "set": "lab"},
		"charm": {"base": "charm_dog_tags", "rar": "legendary", "set": "dock"},
		"implant": {"base": "implant_reflex", "rar": "legendary", "set": null},
	}
	var look: CharacterLook = LookBuilder.from_equipped(loadout)
	assert_eq(look.set_counts, {&"lab": 3, &"dock": 1})
	loadout["charm"]["set"] = "lab"
	loadout["implant"]["set"] = "lab"
	assert_eq(LookBuilder.from_equipped(loadout).set_counts, {&"lab": 5})


func test_result_is_detached_and_does_not_read_transmog_dyes_or_affixes() -> void:
	var loadout: Dictionary = {
		"vest":
		{
			"base": "vest_light",
			"rar": "rare",
			"set": "lab",
			"visual_id": "vest_heavy",
			"look": {"dye": ["red", "green"]},
			"aff": [["dmg_pct", 5, 1.0]],
		},
	}
	var before: Dictionary = loadout.duplicate(true)
	var first: CharacterLook = LookBuilder.from_equipped(loadout)
	var second: CharacterLook = LookBuilder.from_equipped(loadout)
	assert_eq(first.slots, second.slots)
	assert_eq(first.set_counts, second.set_counts)
	assert_eq(first.slots[&"vest"].visual_id, &"vest_light")
	assert_eq(first.slots[&"vest"].dyes, [Color("5f6d68"), Color("2f393b")])
	first.slots[&"vest"].dyes[0] = Color.RED
	first.set_counts[&"lab"] = 4
	assert_eq(second.slots[&"vest"].dyes[0], Color("5f6d68"))
	assert_eq(second.set_counts[&"lab"], 1)
	assert_eq(loadout, before)

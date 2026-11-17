## Every grip file loads and matches the arm rig; every gun with a viewmodel has a grip.
extends GutTest

const METADATA: String = "res://assets/models/characters/player_arm_grips.json"


func _profiles() -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(METADATA)) as Dictionary
	return parsed.get("profiles", {}) as Dictionary


func test_every_grip_loads_with_its_file_id_and_a_rig_profile() -> void:
	var profiles: Dictionary = _profiles()
	var ids: Array = Content.ids(&"grips")
	assert_eq(ids.size(), 22)
	for id: StringName in ids:
		var grip: GripData = Content.get_item(&"grips", id) as GripData
		assert_not_null(grip, String(id))
		if grip == null:
			continue
		assert_eq(grip.id, id, String(id) + " id matches its file")
		assert_true(profiles.has(String(id)), String(id) + " has a profile in player_arm_grips.json")


func test_every_base_gun_with_a_viewmodel_has_a_grip() -> void:
	for id: StringName in Content.ids(&"weapons"):
		var data: WeaponData = Content.weapon(id)
		if String(id).ends_with("_reforged") or data.viewmodel_scene == null:
			continue
		assert_not_null(data.grip, String(id) + " has a grip")
		if data.grip:
			assert_eq(data.grip.id, id, String(id) + " uses its own grip file")


func test_reforged_guns_share_the_base_grip_and_hip_position() -> void:
	for id: StringName in Content.ids(&"weapons"):
		var data: WeaponData = Content.weapon(id)
		if data.upgraded == null:
			continue
		assert_eq(data.upgraded.grip, data.grip, String(id) + " reforged grip")
		assert_eq(data.upgraded.hip_position, data.hip_position, String(id) + " reforged hip_position")


func test_shot_peak_guns() -> void:
	var peaks: Array[StringName] = []
	for id: StringName in Content.ids(&"grips"):
		if (Content.get_item(&"grips", id) as GripData).shot_peak:
			peaks.append(id)
	peaks.sort()
	assert_eq(peaks.size(), 5)
	for id: StringName in [&"bastion_lmg", &"brenner_trench", &"coachman_2b", &"fieldhand_lever", &"grubber_sawnoff"]:
		assert_has(peaks, id)

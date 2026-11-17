## PlayerArmProfiles reads each gun's GripData and still builds today's arm poses.
extends GutTest

const SNAPSHOT: String = "res://tests/fixtures/grips/player_arm_profiles.json"
const TOLERANCE: float = 0.00001


func _snapshot() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT)) as Dictionary


func _assert_floats(actual: Array, expected: Array, label: String) -> void:
	assert_eq(actual.size(), expected.size(), label + " size")
	for index: int in mini(actual.size(), expected.size()):
		assert_almost_eq(float(actual[index]), float(expected[index]), TOLERANCE, "%s[%d]" % [label, index])


func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _assert_hand(hand: PlayerArmProfiles.Hand, expected: Dictionary, label: String) -> void:
	var rotation: Array = _vector(hand.rotation.x) + _vector(hand.rotation.y) + _vector(hand.rotation.z)
	_assert_floats(_vector(hand.wrist), expected["wrist"], label + " wrist")
	_assert_floats(rotation, expected["rotation"], label + " rotation")
	_assert_floats(_vector(hand.shoulder), expected["shoulder"], label + " shoulder")
	_assert_floats([hand.shoulder_lift.x, hand.shoulder_lift.y], expected["shoulder_lift"], label + " shoulder_lift")
	_assert_floats([hand.shoulder_sway.x, hand.shoulder_sway.y], expected["shoulder_sway"], label + " shoulder_sway")
	_assert_floats(_vector(hand.shoulder_sprint_offset), expected["sprint_offset"], label + " sprint offset")


func test_every_grip_matches_the_frozen_snapshot() -> void:
	var snapshot: Dictionary = _snapshot()
	var ids: Array[StringName] = PlayerArmProfiles.weapon_ids()
	assert_eq(ids.size(), 22)
	assert_eq(ids.size(), snapshot.size())
	for id: StringName in ids:
		var expected: Dictionary = snapshot.get(String(id), {})
		assert_false(expected.is_empty(), String(id) + " is in the snapshot")
		var profile: PlayerArmProfiles.Profile = PlayerArmProfiles.profile(Content.weapon(id))
		assert_not_null(profile, String(id))
		if expected.is_empty() or profile == null:
			continue
		assert_eq(profile.id, id)
		assert_eq(String(profile.morph), expected["morph"], String(id) + " morph")
		assert_eq(String(profile.support_part), expected["support_part"], String(id) + " support part")
		_assert_hand(profile.right, expected["right"], String(id) + " right")
		_assert_hand(profile.left, expected["left"], String(id) + " left")


func test_weapon_ids_are_the_sorted_grip_ids() -> void:
	var ids: Array[StringName] = PlayerArmProfiles.weapon_ids()
	for index: int in range(1, ids.size()):
		assert_lt(String(ids[index - 1]), String(ids[index]))
	assert_has(ids, &"rifle_ar")


func test_a_gun_no_code_knows_gets_arms_from_its_grip() -> void:
	var grip: GripData = GripData.new()
	grip.id = &"rifle_ar"
	grip.right_anchor = Vector3(0, -.12, -.1)
	grip.left_anchor = Vector3(0, .2, .02)
	grip.right_shoulder_lift = Vector2(.05, .09)
	grip.support_part = ^"Body/Pump"
	var data: WeaponData = WeaponData.new()
	data.id = &"test_unknown_gun"
	data.hip_position = Vector3(.1, -.2, -.3)
	data.grip = grip
	var profile: PlayerArmProfiles.Profile = PlayerArmProfiles.profile(data)
	assert_not_null(profile)
	if profile == null:
		return
	assert_eq(profile.hip_position, data.hip_position)
	assert_eq(profile.right.shoulder_lift, Vector2(.05, .09))
	assert_eq(profile.support_part, ^"Body/Pump")
	var rifle: PlayerArmProfiles.Profile = PlayerArmProfiles.profile(Content.weapon(&"rifle_ar"))
	assert_ne(profile.right.wrist, rifle.right.wrist, "custom anchor moves the wrist")


func test_a_gun_without_grip_has_no_arms() -> void:
	var data: WeaponData = WeaponData.new()
	data.id = &"test_no_grip"
	assert_null(PlayerArmProfiles.profile(data))
	assert_null(PlayerArmProfiles.profile(null))

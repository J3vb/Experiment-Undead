## Magazine reload motion: rest at both ends, magazine home before ammo lands, hand carries the magazine.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const CENTER: Vector3 = Vector3(0.0, -0.1, -0.2)
const TOP: Vector3 = Vector3(0.0, -0.04, -0.2)
const STARTERS: Array[StringName] = [&"rifle_ar", &"kestrel_smg", &"talon_dmr"]


func _motion() -> ReloadMotion:
	return ReloadMotion.new(CENTER, TOP, Vector3.DOWN)


func test_rest_at_start_and_end() -> void:
	var motion: ReloadMotion = _motion()
	for empty: bool in [false, true]:
		for t: float in [0.0, 1.0]:
			motion.sample(empty, t)
			assert_eq(motion.hand_weight, 0.0)
			assert_eq(motion.mag_offset, Vector3.ZERO)
			assert_eq(motion.roll, 0.0)
			assert_eq(motion.bolt_back, 0.0 if t == 1.0 or not empty else 1.0)


func test_magazine_seated_before_ammo_lands() -> void:
	var motion: ReloadMotion = _motion()
	for empty: bool in [false, true]:
		var seated: float = ReloadMotion.seated_at(empty)
		assert_lt(seated, 0.8)
		var t: float = seated
		while t <= 1.0:
			motion.sample(empty, t)
			assert_eq(motion.mag_offset, Vector3.ZERO, "seated at %.2f" % t)
			t += 0.01
		motion.sample(empty, seated - 0.08)
		assert_gt(motion.mag_offset.length(), 0.001, "magazine still moving before it seats")


func test_hand_carries_the_magazine_while_it_moves() -> void:
	var motion: ReloadMotion = _motion()
	var t: float = 0.12
	while t < ReloadMotion.SEATED:
		motion.sample(false, t)
		assert_almost_eq(motion.hand_weight, 1.0, 0.0001)
		assert_almost_eq(motion.hand_target, CENTER + ReloadMotion.GRAB + motion.mag_offset, Vector3.ONE * 0.01)
		t += 0.01


func test_empty_reload_presses_the_bolt_catch_then_releases_the_bolt() -> void:
	var motion: ReloadMotion = _motion()
	motion.sample(false, 0.84)
	assert_eq(motion.bolt_back, 0.0, "tactical reload never moves the bolt")
	motion.sample(true, 0.765)
	assert_eq(motion.bolt_back, 1.0, "bolt stays locked back until the catch is pressed")
	assert_almost_eq(motion.hand_target, TOP + ReloadMotion.CATCH + ReloadMotion.PRESS, Vector3.ONE * 0.002)
	motion.sample(true, ReloadMotion.BOLT_RELEASE + 0.005)
	assert_eq(motion.bolt_back, 0.0, "bolt home after the release")


func _player_with(id: StringName) -> Player:
	var player: Player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.weapons.set_process(false)
	player.weapons.give(Content.weapon(id)).set_process(false)
	player.weapons.arm_view.set_process(false)
	return player


func test_magazine_guns_get_the_motion_and_others_keep_the_dip() -> void:
	for id: StringName in STARTERS:
		assert_not_null(_player_with(id).weapons.current.pose.motion, String(id))
	assert_null(_player_with(&"brenner_trench").weapons.current.pose.motion, "no Magazine node")
	assert_null(_player_with(&"fieldhand_lever").weapons.current.pose.motion, "loads round by round")


func test_left_arm_reaches_every_key_pose_and_returns_to_its_grip() -> void:
	for id: StringName in STARTERS:
		var player: Player = _player_with(id)
		var weapon: Weapon = player.weapons.current
		var view: PlayerArmView = player.weapons.arm_view
		var magazine: Node3D = weapon.find_child("Magazine", true, false) as Node3D
		var rest: Vector3 = magazine.position
		for empty: bool in [false, true]:
			for t: float in [0.12, 0.25, 0.65, 0.7, 0.75, 0.78, 0.8, 0.86]:
				weapon.state = Weapon.State.RELOADING
				weapon._empty_reload = empty
				weapon._reload_duration = 1.0
				weapon._reload_timer = 1.0 - t
				weapon.pose.update(1.0)
				view.update_pose()
				assert_lt(
					view.left_reach_gap(), 0.02, "%s %s reach at %.2f" % [id, "empty" if empty else "tactical", t]
				)
		weapon.tick(1.0)
		assert_false(weapon.is_reloading())
		weapon.pose.update(1.0)
		view.update_pose()
		var hand: int = view.skeleton.find_bone("hand_L")
		var wrist: Vector3 = weapon.transform * view.profile.left.wrist
		assert_almost_eq(view.skeleton.get_bone_global_pose(hand).origin, wrist, Vector3.ONE * 0.0001)
		assert_eq(magazine.position, rest)

## Runtime arms replace visible placeholders and keep weapon motion, looks and equip ownership intact.
extends GutTest

const APPROVED_POSE: Script = preload("res://tools/character_review.gd")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const COMMON: RarityLook = preload("res://content/looks/rarity/common.tres")
const LEGENDARY: RarityLook = preload("res://content/looks/rarity/legendary.tres")


func _holder() -> WeaponHolder:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	camera.current = true
	var holder: WeaponHolder = WeaponHolder.new()
	camera.add_child(holder)
	holder.setup(null, camera)
	holder.set_process(false)
	return holder


func _give(holder: WeaponHolder, id: StringName = &"rifle_ar") -> Weapon:
	var weapon: Weapon = holder.give(Content.weapon(id))
	weapon.set_process(false)
	return weapon


func _assert_grip_targets(holder: WeaponHolder, delta: Vector3 = Vector3.ZERO) -> void:
	var view: PlayerArmView = holder.arm_view
	var hands: Array[PlayerArmProfiles.Hand] = [view.profile.right, view.profile.left]
	var sides: Array[String] = ["R", "L"]
	for index: int in sides.size():
		var hand: int = view.skeleton.find_bone("hand_" + sides[index])
		var expected: Vector3 = view.weapon.transform * (hands[index].wrist + (delta if index == 1 else Vector3.ZERO))
		assert_almost_eq(view.skeleton.get_bone_global_pose(hand).origin, expected, Vector3.ONE * 0.00001)
		var forearm: int = view.skeleton.get_bone_parent(hand)
		var upper: int = view.skeleton.get_bone_parent(forearm)
		var elbow: Vector3 = view.skeleton.get_bone_global_pose(forearm).origin
		var shoulder: Vector3 = view.skeleton.get_bone_global_pose(upper).origin
		assert_almost_eq(elbow.distance_to(expected), view.skeleton.get_bone_rest(hand).origin.length(), .0001)
		assert_almost_eq(shoulder.distance_to(elbow), view.skeleton.get_bone_rest(forearm).origin.length(), .0001)


func test_rifle_uses_the_imported_rig_and_hides_only_placeholder_hands() -> void:
	var holder: WeaponHolder = _holder()
	var weapon: Weapon = _give(holder)
	var view: PlayerArmView = holder.arm_view
	assert_eq(view.weapon, weapon)
	assert_true(view.is_visible_in_tree())
	assert_eq(view.skeleton.get_bone_count(), 22)
	assert_not_null(view.mesh.skin)
	assert_eq(view.mesh.mesh.get_surface_count(), 3)
	assert_gt(view.process_priority, weapon.process_priority, "pose follows the current frame's weapon animation")
	for part: String in PlayerArmView.PLACEHOLDERS:
		var node: Node3D = weapon.find_child(part, true, false) as Node3D
		assert_not_null(node, part + " contract is retained")
		assert_false(node.visible, part + " is replaced visually")
	assert_true((weapon.find_child("Receiver", true, false) as Node3D).visible)
	assert_not_null(view.find_child("CuffFP_R", true, false))
	assert_not_null(view.find_child("CuffFP_L", true, false))
	_assert_grip_targets(holder)


func test_scoped_arm_meshes_use_the_scope_excluded_layer_without_shadows() -> void:
	var holder: WeaponHolder = _holder()
	var weapon: Weapon = _give(holder, &"talon_dmr")
	var lens: ScopeLens = weapon.find_child("ScopeLens", true, false) as ScopeLens
	for node: Node in holder.arm_view.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		assert_eq(geometry.layers, ScopeLens.VIEWMODEL_LAYER)
		assert_eq(geometry.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_eq(lens.camera.cull_mask & geometry.layers, 0, "scope must not render arms or cuffs")


func test_rifle_looks_are_instance_parameters_and_do_not_mutate_shared_materials() -> void:
	var first: WeaponHolder = _holder()
	var second: WeaponHolder = _holder()
	_give(first)
	_give(second)
	var material: Material = first.arm_view.mesh.get_active_material(0)
	assert_eq(material, second.arm_view.mesh.get_active_material(0))
	GearLook.apply(first.arm_view, LEGENDARY, Color.WHITE, Color.WHITE)
	assert_eq(first.arm_view.mesh.get_instance_shader_parameter(&"trim_color"), LEGENDARY.trim_color)
	assert_eq(second.arm_view.mesh.get_instance_shader_parameter(&"trim_color"), COMMON.trim_color)
	assert_eq(first.arm_view.mesh.get_active_material(0), material)


func test_rifle_sway_ads_kick_and_reload_use_the_current_weapon_transform() -> void:
	var holder: WeaponHolder = _holder()
	var weapon: Weapon = _give(holder)
	for aim: float in [0.0, 0.5, 1.0]:
		weapon.ads_progress = aim
		weapon._process(1.0)
		holder.arm_view.update_pose()
		_assert_grip_targets(holder)
	weapon.fire()
	weapon._process(0.001)
	holder.rotation = Vector3(0.01, -0.02, 0.005)
	holder.arm_view.update_pose()
	_assert_grip_targets(holder)
	weapon.instance.ammo_in_mag = 1
	assert_true(weapon.start_reload())
	weapon._reload_timer = weapon._reload_duration * 0.5
	weapon._process(1.0)
	holder.arm_view.update_pose()
	_assert_grip_targets(holder)


func test_rifle_slots_share_one_arm_rig_through_switch_and_replace() -> void:
	var holder: WeaponHolder = _holder()
	var first: Weapon = _give(holder)
	var original: PlayerArmView = holder.arm_view
	var second: Weapon = _give(holder, &"rifle_ar_reforged")
	assert_eq(holder.arm_view, original)
	assert_eq(original.weapon, second)
	holder.equip(0)
	assert_eq(original.weapon, first)
	var replacement: Weapon = _give(holder, &"rifle_ar_reforged")
	assert_eq(original.weapon, replacement)
	assert_eq(holder.find_children("*", "PlayerArmView", true, false).size(), 1)
	replacement.set_active(false)
	original.update_pose()
	assert_false(original.visible)
	replacement.set_active(true)
	original.update_pose()
	holder.hide()
	assert_false(original.is_visible_in_tree(), "remote and dead-player holder visibility covers the arms")


func test_remote_player_does_not_allocate_first_person_cosmetics() -> void:
	var player: Player = PLAYER.instantiate() as Player
	player.set_multiplayer_authority(2)
	add_child_autofree(player)
	player.weapons.give(Content.weapon(&"rifle_ar"))
	assert_null(player.weapons.arm_view)
	assert_not_null(player.weapons.current, "server-authoritative weapon state still exists")


func test_shotgun_support_hand_follows_pump_and_retains_rest_when_re_equipped() -> void:
	var holder: WeaponHolder = _holder()
	var shotgun: Weapon = _give(holder, &"brenner_trench")
	var pump: Node3D = shotgun.find_child("Bolt", true, false) as Node3D
	var rest: Vector3 = pump.position
	var wrist: Vector3 = holder.arm_view.profile.left.wrist
	shotgun.fire()
	shotgun._process(0.001)
	holder.arm_view.update_pose()
	var delta: Vector3 = pump.get_parent_node_3d().basis * (pump.position - rest)
	_assert_grip_targets(holder, delta)
	assert_gt(delta.z, 0.02)
	_give(holder)
	holder.equip(0)
	for index: int in 30:
		shotgun._process(0.05)
	holder.arm_view.update_pose()
	_assert_grip_targets(holder)
	assert_eq(holder.arm_view.profile.left.wrist, wrist, "moving pump never becomes the authored rest anchor")


func test_every_weapon_and_reforged_variant_selects_only_its_grip_morph() -> void:
	var holder: WeaponHolder = _holder()
	for id: StringName in Content.ids(&"weapons"):
		var weapon: Weapon = _give(holder, id)
		var view: PlayerArmView = holder.arm_view
		assert_eq(view.profile.id, StringName(String(id).trim_suffix("_reforged")))
		var wanted: int = (
			view.mesh.find_blend_shape_by_name(view.profile.morph) if not view.profile.morph.is_empty() else -1
		)
		assert_true(wanted >= 0 or view.profile.morph.is_empty(), String(id) + " has an exported grip")
		for index: int in (view.mesh.mesh as ArrayMesh).get_blend_shape_count():
			assert_eq(view.mesh.get_blend_shape_value(index), 1.0 if index == wanted else 0.0)
		for part: String in PlayerArmView.PLACEHOLDERS:
			var node: Node3D = weapon.find_child(part, true, false) as Node3D
			if node:
				assert_false(node.visible, String(id) + " " + part)


func test_logic_only_weapon_does_not_allocate_or_reuse_visible_cosmetics() -> void:
	var holder: WeaponHolder = _holder()
	var logic: Weapon = holder.give(WeaponData.new())
	logic.set_process(false)
	assert_null(holder.arm_view)
	assert_eq(holder.current, logic)
	var rifle: Weapon = _give(holder)
	var view: PlayerArmView = holder.arm_view
	assert_true(view.visible)
	holder.equip(0)
	view.update_pose()
	assert_false(view.visible)
	assert_null(view.weapon)
	assert_null(view.profile)
	assert_eq(holder.current, logic)
	holder.equip(1)
	assert_eq(view.weapon, rifle)
	assert_true(view.visible)


func test_rifle_hip_preserves_the_approved_imported_joint_pose() -> void:
	var holder: WeaponHolder = _holder()
	_give(holder)
	var original: Node3D = PlayerArmView.ARMS.instantiate() as Node3D
	add_child_autofree(original)
	var skeleton: Skeleton3D = original.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for side: String in ["R", "L"]:
		APPROVED_POSE._rifle_arm(skeleton, side)
		for name: String in ["upperarm_", "forearm_", "hand_"]:
			var bone: int = skeleton.find_bone(name + side)
			var expected: Transform3D = skeleton.get_bone_global_pose(bone)
			var actual: Transform3D = holder.arm_view.skeleton.get_bone_global_pose(bone)
			assert_almost_eq(actual.origin, expected.origin, Vector3.ONE * .00001, name + side)
			assert_true(actual.basis.is_equal_approx(expected.basis), name + side + " approved rotation")


func _assert_arm_update_preserves_weapon_motion(holder: WeaponHolder) -> void:
	var weapon: Weapon = holder.current
	var transform: Transform3D = weapon.transform
	var bolt: Vector3 = weapon.pose._bolt.position if weapon.pose._bolt else Vector3.ZERO
	var magazine: Vector3 = weapon.pose._magazine.position if weapon.pose._magazine else Vector3.ZERO
	var pump: Vector3 = Vector3.ZERO
	if not holder.arm_view.profile.support_part.is_empty():
		var rest: Vector3 = weapon.pose._bolt.get_parent_node_3d().to_global(weapon.pose._bolt_rest)
		pump = weapon.to_local(weapon.pose._bolt.global_position) - weapon.to_local(rest)
	holder.arm_view.update_pose()
	_assert_grip_targets(holder, pump)
	assert_eq(weapon.transform, transform, "arm IK cannot move the weapon")
	if weapon.pose._bolt:
		assert_eq(weapon.pose._bolt.position, bolt, "arm IK cannot move the bolt or pump")
	if weapon.pose._magazine:
		assert_eq(weapon.pose._magazine.position, magazine, "arm IK cannot move the magazine")


func test_all_weapon_definitions_keep_firing_reloads_and_slots_with_the_imported_arms() -> void:
	var holder: WeaponHolder = _holder()
	for id: StringName in Content.ids(&"weapons"):
		var weapon: Weapon = _give(holder, id)
		assert_true(weapon.can_fire(), String(id))
		weapon.fire()
		weapon._process(.001)
		assert_eq(weapon.instance.ammo_in_mag, weapon.data.magazine_size - 1, String(id))
		assert_gt(weapon.position.z, weapon.data.hip_position.z, String(id) + " current kick")
		_assert_arm_update_preserves_weapon_motion(holder)
		for empty: bool in [false, true]:
			if empty:
				weapon.instance.ammo_in_mag = 0
			assert_true(weapon.start_reload(), String(id))
			weapon.tick(weapon._reload_duration * .5)
			weapon._process(.05)
			_assert_arm_update_preserves_weapon_motion(holder)
			var rounds: int = weapon.data.magazine_size if weapon.data.reload_per_round else 1
			weapon.tick(weapon._reload_duration * rounds)
			assert_false(weapon.is_reloading(), String(id) + " reload genuinely completes")
			weapon._process(.05)
			_assert_arm_update_preserves_weapon_motion(holder)
			assert_eq(weapon.instance.ammo_in_mag, weapon.data.magazine_size, String(id))
		holder.cycle(1)
		assert_eq(holder.arm_view.weapon, holder.current)
		assert_true(holder.arm_view.visible)


func test_rifle_item_stat_copy_keeps_base_grip_and_shared_content_unchanged() -> void:
	var holder: WeaponHolder = _holder()
	var base: WeaponData = Content.weapon(&"rifle_ar")
	var item: ItemInstance = ItemInstance.new({"aff": [["mag_pct", 5, 1.0], ["reload_pct", 5, 1.0]]})
	var weapon: Weapon = holder.give(item.weapon_data(base))
	weapon.item = item
	weapon.set_process(false)
	assert_ne(weapon.data, base)
	assert_gt(weapon.data.magazine_size, base.magazine_size)
	assert_eq(holder.arm_view.profile.id, base.id)
	assert_eq(holder.arm_view.weapon, weapon)
	weapon.fire()
	assert_true(weapon.start_reload())
	assert_almost_eq(weapon._reload_duration, base.reload_time * item.weapon_stat(&"reload_time"), .00001)
	weapon._process(.05)
	_assert_arm_update_preserves_weapon_motion(holder)
	assert_eq(base, Content.weapon(&"rifle_ar"), "shared content is retained")


func test_rifle_per_round_reload_keeps_current_arm_contacts_through_every_insert() -> void:
	var holder: WeaponHolder = _holder()
	var data: WeaponData = Content.weapon(&"rifle_ar").duplicate() as WeaponData
	data.reload_per_round = true
	data.magazine_size = 4
	var weapon: Weapon = holder.give(data)
	weapon.set_process(false)
	weapon.instance.ammo_in_mag = 0
	assert_true(weapon.start_reload())
	for index: int in data.magazine_size:
		weapon.tick(weapon._reload_duration)
		weapon._process(.05)
		assert_eq(weapon.instance.ammo_in_mag, index + 1, "each elapsed interval inserts exactly one round")
		assert_eq(weapon.is_reloading(), index + 1 < data.magazine_size)
		_assert_arm_update_preserves_weapon_motion(holder)
	assert_true(holder.arm_view.visible)

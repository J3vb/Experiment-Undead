## First-person gear follows the owner's worn look: vest cuffs and the charm on the primary, nothing when unworn.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const LEGENDARY: RarityLook = preload("res://content/looks/rarity/legendary.tres")
const RARE: RarityLook = preload("res://content/looks/rarity/rare.tres")


func _look(vest: StringName, rarity: StringName, charm: StringName = &"") -> CharacterLook:
	var look: CharacterLook = CharacterLook.new()
	if not vest.is_empty():
		look.slots[&"vest"] = {"visual_id": vest, "rarity": rarity}
	if not charm.is_empty():
		look.slots[&"charm"] = {"visual_id": charm, "rarity": rarity}
	return look


func _local_player() -> Player:
	var player: Player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.weapons.give(Content.weapon(&"rifle_ar"))
	return player


func _cuffs(view: PlayerArmView) -> Array[Node]:
	var cuffs: Array[Node] = []
	for side: String in ["L", "R"]:
		cuffs.append_array(view.find_children("CuffFP_" + side, "", true, false))
	return cuffs


func test_worn_legendary_vest_puts_its_cuffs_on_both_forearms() -> void:
	var player: Player = _local_player()
	player.gear_rig.apply(_look(&"vest_heavy", &"legendary"))
	var view: PlayerArmView = player.weapons.arm_view
	var cuffs: Array[Node] = _cuffs(view)
	assert_eq(cuffs.size(), 2)
	for cuff: Node in cuffs:
		var geometry: GeometryInstance3D = cuff as GeometryInstance3D
		assert_eq(geometry.get_instance_shader_parameter(&"trim_color"), LEGENDARY.trim_color)
		assert_eq(geometry.layers, ScopeLens.VIEWMODEL_LAYER)
		assert_eq(geometry.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var bone: BoneAttachment3D = cuff.get_parent() as BoneAttachment3D
		assert_true(String(bone.bone_name).begins_with("forearm_"))


func test_no_vest_shows_no_cuffs() -> void:
	var player: Player = _local_player()
	player.gear_rig.apply(_look(&"", &""))
	assert_eq(_cuffs(player.weapons.arm_view).size(), 0)


func test_gear_swap_replaces_the_cuffs_without_leftovers() -> void:
	var player: Player = _local_player()
	player.gear_rig.apply(_look(&"vest_heavy", &"legendary"))
	player.gear_rig.apply(_look(&"vest_light", &"rare"))
	var cuffs: Array[Node] = _cuffs(player.weapons.arm_view)
	assert_eq(cuffs.size(), 2)
	for cuff: Node in cuffs:
		assert_eq((cuff as GeometryInstance3D).get_instance_shader_parameter(&"trim_color"), RARE.trim_color)
	player.gear_rig.apply(_look(&"", &""))
	assert_eq(_cuffs(player.weapons.arm_view).size(), 0)


func test_arm_view_made_after_the_look_still_shows_it() -> void:
	var player: Player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.gear_rig.apply(_look(&"vest_medium", &"rare"))
	player.weapons.give(Content.weapon(&"rifle_ar"))
	assert_eq(_cuffs(player.weapons.arm_view).size(), 2)


func test_bad_visual_id_falls_back_to_common_cuffs() -> void:
	var player: Player = _local_player()
	player.gear_rig.apply(_look(&"no_such_vest", &"legendary"))
	var cuffs: Array[Node] = _cuffs(player.weapons.arm_view)
	assert_eq(cuffs.size(), 2)
	var common: RarityLook = Content.get_item(&"looks", &"common") as RarityLook
	assert_eq((cuffs[0] as GeometryInstance3D).get_instance_shader_parameter(&"trim_color"), common.trim_color)


func test_remote_player_with_a_look_builds_no_first_person_gear() -> void:
	var player: Player = PLAYER.instantiate() as Player
	player.set_multiplayer_authority(2)
	add_child_autofree(player)
	player.weapons.give(Content.weapon(&"rifle_ar"))
	player.gear_rig.apply(_look(&"vest_heavy", &"legendary"))
	assert_null(player.weapons.arm_view)


func _charm(view: PlayerArmView) -> Node3D:
	return view.get_node_or_null("Charm") as Node3D


func test_charm_hangs_from_the_rifle_mount_with_its_rarity() -> void:
	var player: Player = _local_player()
	player.gear_rig.apply(_look(&"", &"legendary", &"charm_dog_tags"))
	var view: PlayerArmView = player.weapons.arm_view
	var charm: Node3D = _charm(view)
	assert_not_null(charm)
	assert_eq(charm.get_parent(), view, "the charm never belongs to a gun")
	assert_true(charm.visible)
	var mount: Node3D = player.weapons.current.find_child("CharmMount", true, false) as Node3D
	assert_almost_eq(charm.global_position, mount.global_position, Vector3.ONE * 0.0001)
	for node: Node in charm.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		assert_eq(geometry.get_instance_shader_parameter(&"trim_color"), LEGENDARY.trim_color)
		assert_eq(geometry.layers, ScopeLens.VIEWMODEL_LAYER)


func test_charm_hides_on_a_sidearm_and_survives_a_primary_replaced_meanwhile() -> void:
	var player: Player = _local_player()
	player.weapons.give(Content.weapon(&"pistol_service"))
	player.gear_rig.apply(_look(&"", &"rare", &"charm_coin"))
	var view: PlayerArmView = player.weapons.arm_view
	assert_false(_charm(view).visible, "no mount on a sidearm")
	var old: Weapon = player.weapons.weapons[0]
	player.weapons.replace(old, Content.weapon(&"talon_dmr"))
	await wait_physics_frames(2)
	assert_not_null(_charm(view), "freeing the old primary kept the charm")
	player.weapons.equip(0)
	assert_true(_charm(view).visible)
	var mount: Node3D = player.weapons.current.find_child("CharmMount", true, false) as Node3D
	assert_almost_eq(_charm(view).global_position, mount.global_position, Vector3.ONE * 0.0001)


func test_unequipped_charm_is_removed() -> void:
	var player: Player = _local_player()
	player.gear_rig.apply(_look(&"vest_light", &"common", &"charm_vial"))
	player.gear_rig.apply(_look(&"vest_light", &"common"))
	assert_null(_charm(player.weapons.arm_view))


func test_swing_tilts_with_motion_and_settles_at_rest() -> void:
	var swing: CharmSwing = CharmSwing.new()
	var mount: Transform3D = Transform3D.IDENTITY
	for frame: int in 10:
		mount.origin.x += 0.002 * frame
		swing.step(mount, 1.0 / 60.0)
	assert_gt(swing.angle.length(), 0.01, "a sideways push swings the charm")
	for frame: int in 300:
		swing.step(mount, 1.0 / 60.0)
	assert_lt(swing.angle.length(), 0.001, "it settles once the gun stops")
	assert_lte(absf(swing.angle.x), CharmSwing.MAX_ANGLE)


func test_implant_module_rides_the_left_forearm_without_its_neck_port() -> void:
	var player: Player = _local_player()
	var look: CharacterLook = _look(&"", &"")
	look.slots[&"implant"] = {"visual_id": &"implant_reflex", "rarity": &"rare"}
	player.gear_rig.apply(look)
	var view: PlayerArmView = player.weapons.arm_view
	var holder: BoneAttachment3D = view.find_child("Implant", true, false) as BoneAttachment3D
	assert_not_null(holder)
	assert_eq(holder.bone_name, &"forearm_L")
	assert_not_null(holder.find_child("Module", true, false))
	assert_null(holder.find_child("Port", true, false), "the neck port is not seen in first person")
	for node: Node in holder.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		assert_eq(geometry.get_instance_shader_parameter(&"trim_color"), RARE.trim_color)
		assert_eq(geometry.layers, ScopeLens.VIEWMODEL_LAYER)


func test_implant_swaps_and_clears_with_the_look() -> void:
	var player: Player = _local_player()
	var look: CharacterLook = _look(&"", &"")
	look.slots[&"implant"] = {"visual_id": &"implant_lung", "rarity": &"common"}
	player.gear_rig.apply(look)
	look = _look(&"", &"")
	look.slots[&"implant"] = {"visual_id": &"implant_ocular", "rarity": &"legendary"}
	player.gear_rig.apply(look)
	var view: PlayerArmView = player.weapons.arm_view
	assert_eq(view.find_children("Implant", "BoneAttachment3D", true, false).size(), 1)
	player.gear_rig.apply(_look(&"", &""))
	assert_null(view.find_child("Implant", true, false))

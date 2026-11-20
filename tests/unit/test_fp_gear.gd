## First-person gear follows the owner's worn look: vest cuffs by frame and rarity, nothing when unworn.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const LEGENDARY: RarityLook = preload("res://content/looks/rarity/legendary.tres")
const RARE: RarityLook = preload("res://content/looks/rarity/rare.tres")


func _look(vest: StringName, rarity: StringName) -> CharacterLook:
	var look: CharacterLook = CharacterLook.new()
	if not vest.is_empty():
		look.slots[&"vest"] = {"visual_id": vest, "rarity": rarity}
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

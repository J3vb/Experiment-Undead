## Bastion's roster numbers, Tier I upgrade and loot presentation stay aligned.
extends GutTest


func test_bastion_matches_its_roster_row() -> void:
	var gun: WeaponData = Content.weapon(&"bastion_lmg")
	assert_not_null(gun)
	if gun == null:
		return
	assert_eq(gun.display_name, "Bastion")
	assert_almost_eq(gun.damage, 70.0 * 0.57, 0.001)
	assert_almost_eq(gun.min_damage, 49.0 * 0.57, 0.001)
	assert_eq(gun.pellets, 1)
	assert_eq(gun.head_multiplier, 2.5)
	assert_eq(gun.fire_mode, WeaponData.FireMode.AUTO)
	assert_eq(gun.rounds_per_minute, 800.0)
	assert_eq(gun.spin_up_time, 0.5)
	assert_eq(gun.magazine_size, 150)
	assert_eq(gun.starting_reserve, 300)
	assert_eq(gun.max_reserve, 300)
	assert_eq(gun.reload_time, 7.0)
	assert_eq(gun.empty_reload_time, 8.0)
	assert_eq(gun.ads_time, 0.4)
	assert_eq(gun.move_speed_multiplier, 0.8)
	assert_eq(gun.crate_weight, 0.5)
	assert_eq(gun.loot_tags, Array([&"lmg", &"belt"], TYPE_STRING_NAME, &"", null))
	assert_eq(gun.get_meta(&"unlock_level"), 20)
	assert_eq(gun.get_meta(&"min_rarity"), &"rare")
	assert_eq(gun.cost, 0)


func test_bastion_is_the_slowest_base_gun_to_move_and_reload() -> void:
	var bastion: WeaponData = Content.weapon(&"bastion_lmg")
	for id: StringName in Content.ids(&"weapons"):
		if id == bastion.id or String(id).ends_with("_reforged"):
			continue
		var other: WeaponData = Content.weapon(id)
		assert_lt(bastion.move_speed_multiplier, other.move_speed_multiplier, String(id) + " moves faster")
		assert_gt(bastion.reload_time, other.reload_time, String(id) + " reloads faster")
		assert_gt(bastion.empty_reload_time, other.empty_reload_time, String(id) + " empty reload is faster")


func test_reforged_keeps_the_ramp_and_follows_tier_one() -> void:
	var gun: WeaponData = Content.weapon(&"bastion_lmg")
	var up: WeaponData = gun.upgraded
	assert_not_null(up)
	if up == null:
		return
	assert_eq(up.id, &"bastion_lmg_reforged")
	assert_eq(up.display_name, "Bastion Reforged")
	assert_almost_eq(up.damage, gun.damage * 2.0, 0.001)
	assert_almost_eq(up.min_damage, gun.min_damage * 2.0, 0.001)
	assert_eq(up.magazine_size, 225)
	assert_eq(up.starting_reserve, 600)
	assert_eq(up.max_reserve, 600)
	assert_eq(up.rounds_per_minute, gun.rounds_per_minute)
	assert_eq(up.spin_up_time, gun.spin_up_time)
	assert_eq(up.loot_tags, gun.loot_tags)
	assert_eq(up.viewmodel_scene, gun.viewmodel_scene)
	assert_eq(up.get_meta(&"unlock_level"), gun.get_meta(&"unlock_level"))
	assert_eq(up.get_meta(&"min_rarity"), gun.get_meta(&"min_rarity"))


func test_bastion_is_in_the_vault_pool_and_has_no_wall_buy() -> void:
	var map: PackedScene = load("res://levels/halcyon_labs/map.tscn") as PackedScene
	var scene: SceneState = map.get_state()
	var gun: WeaponData = Content.weapon(&"bastion_lmg")
	var in_pool: bool = false
	for node_index: int in scene.get_node_count():
		for property_index: int in scene.get_node_property_count(node_index):
			var property: StringName = scene.get_node_property_name(node_index, property_index)
			var value: Variant = scene.get_node_property_value(node_index, property_index)
			if property == &"pool":
				in_pool = gun in value
			if property == &"weapon":
				assert_ne(value, gun, "Bastion has no wall buy")
	assert_true(in_pool, "Bastion is obtainable from the Specimen Vault")


func test_viewmodel_has_hands_and_the_spin_up_layer() -> void:
	var gun: WeaponData = Content.weapon(&"bastion_lmg")
	var vm: Node3D = gun.viewmodel_scene.instantiate() as Node3D
	for part: String in ["Belt", "FeedCover", "Bolt", "Muzzle", "Bipod", "CarryHandle", "HandRight", "HandLeft"]:
		assert_not_null(vm.find_child(part, true, false), part)
	var audio: AudioStreamPlayer = vm.find_child("SpinUpAudio", true, false) as AudioStreamPlayer
	assert_not_null(audio)
	if audio:
		assert_eq(audio.bus, &"Weapons")
		assert_false(audio.autoplay)
	assert_not_null(vm.find_child("FlashLight", true, false))
	assert_not_null(vm.find_child("FlashMesh", true, false))
	assert_almost_eq(gun.ads_position.y + 0.112, 0.0, 0.001, "iron sight at eye height")
	vm.free()

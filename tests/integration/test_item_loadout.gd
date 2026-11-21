## A real match loads equipped item stats from the local character without using Pack guns.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const PROFILE_ID: StringName = &"test_item_loadout"
var _profile_path: String = CharacterProfile.directory() + "test_item_loadout.json"

var _loot_before: Dictionary


func before_each() -> void:
	_loot_before = Content._by_type[&"loot"].duplicate()
	Content._by_type[&"loot"][&"test_max_health"] = "res://tests/fixtures/loot/test_max_health.tres"
	_remove_profile()


func after_each() -> void:
	Content._by_type[&"loot"] = _loot_before
	_remove_profile()


func _remove_profile() -> void:
	for path: String in [_profile_path, _profile_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_character_sidearm_and_gear_are_applied_at_run_start() -> void:
	var sidearm: Dictionary = {"uid": "sidearm", "base": "hollis_44", "rar": "rare", "aff": [["reload_pct", 5, 1.0]]}
	var vest: Dictionary = {"uid": "vest", "base": "vest_medium", "rar": "rare", "aff": [["test_max_health", 1, 1.0]]}
	var profile: CharacterProfile = (
		CharacterProfile
		. from_dict(
			{
				"id": String(PROFILE_ID),
				"loadout": {"sidearm": sidearm, "vest": vest, "primary": {"base": "mako_pdw"}},
				"pack": [{"base": "atlas_auto"}],
			}
		)
	)
	assert_eq(profile.save(), OK)
	var saved_before: String = FileAccess.get_file_as_string(_profile_path)
	var session: GameSession = SESSION.instantiate() as GameSession
	session.profile_id = PROFILE_ID
	session.rng_seed = 1234
	add_child_autofree(session)
	session.director.stop()
	var player: Player = session.get_players()[0]
	var item_gun: Weapon
	for weapon: Weapon in player.weapons.weapons:
		assert_ne(weapon.data.id, &"mako_pdw", "The loadout Primary waits until round 5")
		assert_ne(weapon.data.id, &"atlas_auto", "Pack guns stay out of this run")
		if weapon.data.id == &"hollis_44":
			item_gun = weapon
	assert_not_null(item_gun)
	if item_gun != null:
		assert_not_null(item_gun.item)
		assert_almost_eq(item_gun._stat(&"reload_time"), 1.0 / 1.2, 0.0001)
	assert_eq(player.health.max_health, 140.0)
	assert_eq(FileAccess.get_file_as_string(_profile_path), saved_before)


func test_real_vest_regen_roll_reduces_four_second_delay_without_changing_content() -> void:
	var saved: Dictionary = _gear_item(&"vest_medium", [["regen_delay", 5, 1.0]])
	var before: Dictionary = saved.duplicate(true)
	var affix: AffixData = Content.get_item(&"loot", &"regen_delay") as AffixData
	var player: Player = _player_with_gear(saved)
	assert_eq(ItemRoller.affix_value(&"regen_delay", 5, 1.0), 1.0, "The saved roll remains a positive magnitude")
	assert_almost_eq(player.health.regen_delay, 3.0, 0.0001)
	assert_eq(affix.tiers[4].high, 1.0)
	assert_eq(affix.text, "-{v} s before health regen")
	assert_eq(affix.op, "flat")
	assert_eq(saved, before)
	player.equip_gear([])
	assert_almost_eq(player.health.regen_delay, 4.0, 0.0001, "Removing the vest restores the base delay")


func test_real_gear_all_damage_and_mule_affixes_reach_weapon_snapshots() -> void:
	var saved: Dictionary = _gear_item(&"charm_dog_tags", [["all_damage", 5, 1.0], ["mule", 5, 1.0]])
	var before: Dictionary = saved.duplicate(true)
	var base: WeaponData = Content.weapon(&"rifle_ar")
	var original: Array = [base.damage, base.min_damage, base.starting_reserve, base.max_reserve]
	var player: Player = _player_with_gear(saved)
	var weapon_item: ItemInstance = ItemInstance.new({"base": "rifle_ar", "aff": [], "imp": []})
	var snapshot: WeaponData = weapon_item.weapon_data(base, player.stats)
	assert_ne(snapshot, base)
	assert_almost_eq(snapshot.damage, base.damage * 1.06, 0.0001)
	assert_almost_eq(snapshot.min_damage, base.min_damage * 1.06, 0.0001)
	assert_eq(snapshot.starting_reserve, roundi(base.starting_reserve * 1.15))
	assert_eq(snapshot.max_reserve, roundi(base.max_reserve * 1.15))
	assert_eq([base.damage, base.min_damage, base.starting_reserve, base.max_reserve], original)
	assert_same(Content.weapon(&"rifle_ar"), base)
	assert_eq(saved, before)


func test_real_gear_reload_and_headshot_focus_reach_player_weapon_stat_hooks() -> void:
	var saved: Dictionary = _gear_item(&"implant_reflex", [["reload_focus", 5, 1.0], ["headshot_focus", 5, 1.0]])
	var before: Dictionary = saved.duplicate(true)
	var player: Player = _player_with_gear(saved)
	assert_almost_eq(player.get_stat(&"reload_time"), 1.0 / 1.1, 0.0001)
	assert_almost_eq(player.get_stat(&"head_damage"), 1.12, 0.0001)
	var weapon_item: ItemInstance = ItemInstance.new({"aff": [["reload_pct", 5, 1.0], ["hs_pct", 5, 1.0]]})
	assert_almost_eq(player.get_stat(&"reload_time", 1.0, weapon_item.stats), 1.0 / 1.3, 0.0001)
	assert_almost_eq(player.get_stat(&"head_damage", 1.0, weapon_item.stats), 1.42, 0.0001)
	assert_eq(saved, before)


func test_real_gear_sprint_duration_reaches_the_stamina_consumer() -> void:
	var saved: Dictionary = _gear_item(&"vest_light", [["sprint_duration", 5, 1.0]])
	var before: Dictionary = saved.duplicate(true)
	var player: Player = _player_with_gear(saved)
	assert_almost_eq(player.get_stat(&"sprint_time"), 1.4, 0.0001)
	player.sprint_left = 0.0
	player.is_sprinting = false
	player.moves.tick_stamina(player, player.sprint_cooldown)
	assert_almost_eq(player.sprint_left, player.sprint_time * 1.4, 0.0001)
	assert_eq(saved, before)


func _gear_item(base: StringName, affixes: Array) -> Dictionary:
	var gear: GearBaseData = Content.get_item(&"loot", base) as GearBaseData
	return {"uid": "consumer_gear", "base": String(gear.id), "rar": "rare", "ilvl": 50, "aff": affixes, "imp": []}


func _player_with_gear(item: Dictionary) -> Player:
	var player: Player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.equip_gear([item])
	return player

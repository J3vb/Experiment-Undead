## A real match loads equipped item stats from the local character without using Pack guns.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const PROFILE_ID: StringName = &"test_item_loadout"
const PROFILE_PATH: String = "user://characters/test_item_loadout.json"

var _loot_before: Dictionary


func before_each() -> void:
	_loot_before = Content._by_type[&"loot"].duplicate()
	Content._by_type[&"loot"][&"test_max_health"] = "res://tests/fixtures/loot/test_max_health.tres"
	_remove_profile()


func after_each() -> void:
	Content._by_type[&"loot"] = _loot_before
	_remove_profile()


func _remove_profile() -> void:
	for path: String in [PROFILE_PATH, PROFILE_PATH + ".tmp"]:
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
	var saved_before: String = FileAccess.get_file_as_string(PROFILE_PATH)
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
	assert_eq(FileAccess.get_file_as_string(PROFILE_PATH), saved_before)

## A real solo run: E on a Pack vest or charm wears it, swaps the old piece into the Pack and banks the new loadout.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const PROFILE_ID: StringName = &"test_wear_gear_mid_run"

var session: GameSession
var player: Player
var _profile_path: String = CharacterProfile.directory() + "test_wear_gear_mid_run.json"
var _loot_before: Dictionary


func before_each() -> void:
	_loot_before = Content._by_type[&"loot"].duplicate()
	Content._by_type[&"loot"][&"test_max_health"] = "res://tests/fixtures/loot/test_max_health.tres"
	_remove_profile()
	var profile: CharacterProfile = CharacterProfile.from_dict(
		{"id": String(PROFILE_ID), "loadout": {"vest": _vest("old_vest", 1.0)}}
	)
	assert_eq(profile.save(), OK)
	session = SESSION.instantiate() as GameSession
	session.profile_id = PROFILE_ID
	session.rng_seed = 1234
	add_child_autofree(session)
	session.director.stop()
	player = session.get_players()[0]


func after_each() -> void:
	Content._by_type[&"loot"] = _loot_before
	_remove_profile()


func _remove_profile() -> void:
	for path: String in [_profile_path, _profile_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## q 1.0 rolls +40 max health, q 0.0 rolls +10.
func _vest(uid: String, quality: float) -> Dictionary:
	return {"uid": uid, "base": "vest_medium", "rar": "rare", "ilvl": 30, "aff": [["test_max_health", 1, quality]]}


func _wear(uid: String) -> void:
	session.loot.request_equip(uid)
	await wait_physics_frames(2)


func test_wearing_a_pack_vest_swaps_it_with_the_worn_one() -> void:
	assert_eq(player.health.max_health, 140.0, "the saved vest is worn at spawn")
	session.loot.pack.add({"uid": "gun", "base": "rifle_ar", "rar": "common"})
	session.loot.pack.add(_vest("new_vest", 0.0))
	await _wear("new_vest")
	assert_eq(session.profile.loadout["vest"]["uid"], "new_vest")
	assert_eq(session.loot.pack.items.size(), 2, "a swap never grows the Pack")
	assert_eq(session.loot.pack.items[1]["uid"], "old_vest", "the old vest takes the new one's Pack slot")
	assert_eq(player.health.max_health, 110.0)
	assert_eq(player.loadout_sync.gear.size(), 1)
	assert_eq(player.loadout_sync.gear[0]["uid"], "new_vest")


func test_swapping_a_health_vest_off_and_on_never_heals() -> void:
	session.loot.pack.add(_vest("small_vest", 0.0))
	player.health.current = 60.0
	await _wear("small_vest")
	assert_eq(player.health.max_health, 110.0)
	assert_eq(player.health.current, 60.0)
	await _wear("old_vest")
	assert_eq(player.health.max_health, 140.0)
	assert_eq(player.health.current, 60.0, "putting the big vest back on does not heal")


func test_held_item_gun_gets_gear_damage_and_stays_in_hand_with_its_ammo() -> void:
	var item: ItemInstance = ItemInstance.new({"uid": "held_ar", "base": "rifle_ar", "rar": "common", "aff": []})
	var weapon: Weapon = ItemLoadout.equip_weapon(player, item, null)
	player.weapons.equip(player.weapons.weapons.find(weapon))
	weapon.instance.ammo_in_mag = 7
	var damage: float = weapon.data.damage
	var held: int = player.weapons.weapons.size()
	session.loot.pack.add(
		{"uid": "tags", "base": "charm_dog_tags", "rar": "rare", "ilvl": 50, "aff": [["all_damage", 5, 1.0]]}
	)
	await _wear("tags")
	assert_same(player.weapons.current, weapon, "the same gun stays in hand")
	assert_eq(player.weapons.weapons.size(), held)
	assert_eq(weapon.instance.ammo_in_mag, 7)
	assert_almost_eq(weapon.data.damage, damage * 1.06, 0.0001)


func test_downed_players_cannot_swap_gear() -> void:
	session.loot.pack.add(_vest("new_vest", 0.0))
	player.is_downed = true
	await _wear("new_vest")
	player.is_downed = false
	assert_eq(session.profile.loadout["vest"]["uid"], "old_vest")
	assert_eq(session.loot.pack.items[0]["uid"], "new_vest")


func test_bank_saves_the_worn_vest_and_stashes_the_old_one() -> void:
	session.loot.pack.add(_vest("new_vest", 0.0))
	await _wear("new_vest")
	session.match_end.bank_run_xp()
	var saved: CharacterProfile = CharacterProfile.load_or_create(PROFILE_ID)
	assert_eq(saved.loadout["vest"]["uid"], "new_vest")
	var stashed: Array[String] = []
	for entry: Dictionary in saved.stash:
		if not entry.is_empty():
			stashed.append(str(entry.get("uid", "")))
	assert_eq(stashed, ["old_vest"])
	session.loot.pack.add(_vest("late_vest", 0.0))
	await _wear("late_vest")
	assert_eq(session.profile.loadout["vest"]["uid"], "new_vest", "no swaps after the run is banked")

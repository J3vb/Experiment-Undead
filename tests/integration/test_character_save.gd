## Real match saves preserve character XP and inventory across banking and scene restarts.
extends GutTest

const SESSION: PackedScene = preload("res://tests/integration/character_save_session.tscn")
const ID: StringName = &"test_character_session"
const PATH: String = "user://characters/test_character_session.json"
const START_XP: int = 450

var session: GameSession
var player: Player


func before_each() -> void:
	_remove_files()
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	profile.total_xp = START_XP
	assert_eq(profile.save(), OK)
	session = SESSION.instantiate() as GameSession
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 10.0, "navmesh ready")
	session.director.stop()
	session.loot.drop_chance_override = 0.0
	player = session.get_players()[0]


func after_each() -> void:
	get_tree().paused = false
	_remove_files()


func _remove_files() -> void:
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_kill_and_round_xp_survive_game_over_and_next_session() -> void:
	assert_eq(session.progression.get_level(player), 1)
	var zombie: Zombie = session.spawner.spawn(Content.enemy(&"zombie_walker"), 1, session.wave_rules)
	assert_not_null(zombie)
	session.director.round_number = 1
	session.director.phase = WaveDirector.Phase.CLEARING
	watch_signals(Events)
	zombie.health.take_damage(DamageInfo.create(10000.0, player))
	await wait_for_signal(Events.round_ended, 2.0)
	var run_xp: int = zombie.data.xp_reward + session.progression.rules.round_clear_xp_per_round
	assert_eq(session.progression.get_xp(player), run_xp)
	player.take_damage(DamageInfo.create(10000.0, null))
	assert_true(session.is_over)
	await wait_for_signal(Events.game_over, 2.0)
	var stats: Dictionary = get_signal_parameters(Events, "game_over")[0]
	assert_eq(stats["start_total_xp"], START_XP)
	assert_eq(stats["total_xp"], START_XP + run_xp)
	assert_eq(int(SaveFile.read(PATH)["total_xp"]), START_XP + run_xp)
	session.bank_run_xp()
	assert_eq(int(SaveFile.read(PATH)["total_xp"]), START_XP + run_xp)
	session.free()
	session = SESSION.instantiate() as GameSession
	add_child_autofree(session)
	player = session.get_players()[0]
	assert_eq(session.progression.get_xp(player), 0)
	assert_eq(session.progression.get_total_xp(player), START_XP + run_xp)
	assert_eq(session.progression.get_level(player), 2)


func test_exfil_banks_after_bonus_once() -> void:
	session.progression.add_xp(player, 101)
	session.finish_exfil()
	session.finish_exfil()
	session.bank_run_xp()
	assert_eq(session.progression.get_xp(player), 151)
	assert_eq(int(SaveFile.read(PATH)["total_xp"]), START_XP + 151)
	await wait_seconds(0.05)


func test_inventory_and_unknown_item_keys_survive_match_save_and_load() -> void:
	session.free()
	var profile: CharacterProfile = CharacterProfile.load_or_create(ID)
	var item: Dictionary = {
		"v": 1,
		"uid": "stashed",
		"base": "rifle_ar",
		"rar": "rare",
		"ilvl": 12,
		"aff": [["removed_affix", 2, 0.25]],
		"imp": ["reclaimer", 0.5],
		"trait": null,
		"set": null,
		"craft": {"future_lock": true},
		"future": [1, null, {"kept": true}],
	}
	profile.stash[17] = item
	profile.loadout["primary"] = item.duplicate(true)
	profile.loadout["primary"]["uid"] = "equipped"
	assert_eq(profile.save(), OK)
	var expected: Dictionary = SaveFile.read(PATH)
	session = SESSION.instantiate() as GameSession
	add_child_autofree(session)
	player = session.get_players()[0]
	session.progression.add_xp(player, 75)
	session.bank_run_xp()
	var loaded: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(loaded.total_xp, START_XP + 75)
	assert_eq(loaded.stash, expected["stash"])
	assert_eq(loaded.loadout, expected["loadout"])
	assert_eq(loaded.stash.size(), 60)
	assert_eq(loaded.stash[17]["future"], expected["stash"][17]["future"])
	assert_eq(loaded.loadout["primary"]["uid"], "equipped")
	assert_eq(loaded.loadout["primary"]["craft"], expected["loadout"]["primary"]["craft"])


func test_old_v1_save_banks_xp_with_empty_inventory() -> void:
	session.free()
	assert_eq(SaveFile.write(PATH, {"id": String(ID), "total_xp": START_XP}), OK)
	session = SESSION.instantiate() as GameSession
	add_child_autofree(session)
	player = session.get_players()[0]
	session.progression.add_xp(player, 75)
	session.bank_run_xp()
	var loaded: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(loaded.total_xp, START_XP + 75)
	assert_eq(loaded.stash.size(), 60)
	for item: Dictionary in loaded.stash:
		assert_eq(item, {})
	assert_eq(loaded.loadout, {"primary": {}, "sidearm": {}, "vest": {}, "charm": {}, "implant": {}})
	assert_eq(int(SaveFile.read(PATH)["save_version"]), 1)


func test_restart_mid_run_banks_once() -> void:
	# A root scene lets reload_current_scene exercise the real restart path while GUT stays alive.
	var runner_scene: Node = get_tree().current_scene
	remove_child(session)
	get_tree().root.add_child(session)
	get_tree().current_scene = session
	session.progression.add_xp(player, 75)
	session.restart()
	session.bank_run_xp()
	assert_eq(int(SaveFile.read(PATH)["total_xp"]), START_XP + 75)
	await wait_process_frames(2)
	session = get_tree().current_scene as GameSession
	get_tree().current_scene = runner_scene
	assert_not_null(session)
	if session == null:
		return
	player = session.get_players()[0]
	assert_eq(session.progression.get_total_xp(player), START_XP + 75)
	assert_eq(session.progression.get_level(player), 2)
	session.bank_run_xp()
	session.bank_run_xp()
	assert_eq(int(SaveFile.read(PATH)["total_xp"]), START_XP + 75)
	session.free()


func test_empty_profile_id_does_not_load_or_save() -> void:
	session.free()
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	add_child_autofree(session)
	player = session.get_players()[0]
	assert_eq(session.progression.get_total_xp(player), 0)
	session.progression.add_xp(player, 100)
	session.bank_run_xp()
	assert_eq(int(SaveFile.read(PATH)["total_xp"]), START_XP)


func test_window_close_banks_once() -> void:
	session.progression.add_xp(player, 75)
	session.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	session.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	session.bank_run_xp()
	assert_eq(int(SaveFile.read(PATH)["total_xp"]), START_XP + 75)


func test_pause_main_menu_banks_before_leaving() -> void:
	var runner_scene: Node = get_tree().current_scene
	remove_child(session)
	get_tree().root.add_child(session)
	get_tree().current_scene = session
	session.progression.add_xp(player, 75)
	session.loot.pack.add({"uid": "menu-exit", "base": "vest_light", "rar": "common"})
	session._set_paused(true)
	(session.hud.get_node("Root/PausePanel/Menu/MainMenu") as Button).pressed.emit()
	assert_eq(int(SaveFile.read(PATH)["total_xp"]), START_XP + 75)
	await wait_process_frames(2)
	assert_eq(CharacterProfile.load_or_create(ID).stash[0].get("uid"), "menu-exit")
	var menu: Node = get_tree().current_scene
	get_tree().current_scene = runner_scene
	assert_false(get_tree().paused)
	assert_eq(menu.scene_file_path, "res://systems/ui/main_menu.tscn")
	menu.free()


func test_pack_is_saved_on_death_and_banking_is_idempotent() -> void:
	var item: Dictionary = {"uid": "kept-on-death", "base": "vest_light", "rar": "rare", "ilvl": 17}
	assert_true(session.loot.pack.add(item))
	player.take_damage(DamageInfo.create(10000.0, null))
	await wait_until(func() -> bool: return session.hud.results_screen.visible, 2.0, "death results shown")
	session.bank_run_xp()
	var saved: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(saved.stash[0].uid, "kept-on-death")
	assert_eq(saved.stash[1], {})
	assert_eq(session.loot.results(), {"loot": [item], "loot_lost": 0})
	assert_true(session.loot.pack.items.is_empty())
	assert_eq(session.hud.results_screen.loot_items.get_child_count(), 1)


func test_stash_full_keeps_what_fits_saves_and_reports_overflow() -> void:
	for slot: int in CharacterProfile.STASH_SIZE - 1:
		session._profile.stash[slot] = {"uid": "old-%d" % slot}
	for index: int in 3:
		session.loot.pack.add({"uid": "new-%d" % index, "base": "vest_light", "rar": "common"})
	var lost_before: int = Log.event_counts.get("loot.stash_item_lost", 0)
	session.finish_exfil()
	await wait_until(func() -> bool: return session.hud.results_screen.visible, 2.0, "results shown")
	var saved: CharacterProfile = CharacterProfile.load_or_create(ID)
	assert_eq(saved.stash[59].uid, "new-0")
	assert_eq(saved.stash[58].uid, "old-58")
	assert_eq(session.loot.lost, 2)
	assert_eq(Log.event_counts.get("loot.stash_item_lost", 0) - lost_before, 2)
	assert_eq(session.hud.results_screen.loot_status.text, "Stash full · 1 kept, 2 items lost")
	session.bank_run_xp()
	assert_eq(session.loot.lost, 2)

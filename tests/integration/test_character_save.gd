## Real match XP persists across death, exfil and a scene restart without double banking.
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
	session._set_paused(true)
	(session.hud.get_node("Root/PausePanel/Menu/MainMenu") as Button).pressed.emit()
	assert_eq(int(SaveFile.read(PATH)["total_xp"]), START_XP + 75)
	await wait_process_frames(2)
	var menu: Node = get_tree().current_scene
	get_tree().current_scene = runner_scene
	assert_false(get_tree().paused)
	assert_eq(menu.scene_file_path, "res://systems/ui/main_menu.tscn")
	menu.free()

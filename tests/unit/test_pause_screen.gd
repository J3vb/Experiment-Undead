## Pause, settings in pause and results run through the UI router in a headless match.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")
const PAUSE: PackedScene = preload("res://systems/ui/pause_screen.tscn")
const LEVEL_PATH: String = "user://test_pause_screen_level.tscn"
const SESSION_PATH: String = "user://test_pause_screen_session.tscn"

var _runner: Node
var _root: ScreenData


func before_each() -> void:
	_runner = get_tree().current_scene
	_root = UI._root


func after_each() -> void:
	UI._root = _root
	while UI.top() != &"":
		UI.pop()
	get_tree().paused = false
	var scene: Node = get_tree().current_scene
	get_tree().current_scene = _runner
	if is_instance_valid(scene) and scene != _runner:
		scene.free()
	for path: String in [LEVEL_PATH, SESSION_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## A match on an empty map, saved to a file so UI.reload() can load it again.
func _start_match() -> GameSession:
	var map: Level = Level.new()
	var level: PackedScene = PackedScene.new()
	level.pack(map)
	map.free()
	ResourceSaver.save(level, LEVEL_PATH)
	var template: GameSession = SESSION.instantiate() as GameSession
	template.level_scene = load(LEVEL_PATH) as PackedScene
	template.profile_id = &""
	template.rng_seed = 7
	template.restart_delay = 0.01
	var packed: PackedScene = PackedScene.new()
	packed.pack(template)
	template.free()
	ResourceSaver.save(packed, SESSION_PATH)
	var session: GameSession = (load(SESSION_PATH) as PackedScene).instantiate() as GameSession
	get_tree().root.add_child(session)
	get_tree().current_scene = session
	UI._root = Content.get_item(&"screens", &"match") as ScreenData
	return session


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)


func _top_screen() -> Node:
	return UI._stack.back()["layer"].get_child(0) if not UI._stack.is_empty() else null


func test_pause_menu_keeps_its_buttons_order_and_focus() -> void:
	var pause: PauseScreen = PAUSE.instantiate() as PauseScreen
	add_child_autofree(pause)
	assert_eq(pause.main_menu_button.text, "Main menu")
	assert_eq(pause.quit_button.text, "Quit game")
	assert_lt(pause.main_menu_button.get_index(), pause.quit_button.get_index())
	assert_true(pause.resume_button.has_focus())
	assert_eq(pause.theme.default_font_size, 24)
	assert_eq(pause.color, Color(0.043, 0.063, 0.078, 0.88))


func test_pause_action_pushes_pause_and_esc_closes_it() -> void:
	var session: GameSession = _start_match()
	_press(&"pause")
	assert_eq(UI.top(), &"pause")
	assert_true(get_tree().paused)
	assert_eq((_top_screen().get_parent() as CanvasLayer).layer, 30)
	assert_true(UI.mouse_should_be_free(), "pause frees the mouse")
	_press(&"pause")
	assert_eq(UI.top(), &"", "Esc closes pause and does not reopen it")
	await wait_process_frames(1)
	assert_false(get_tree().paused)
	assert_false(UI.mouse_should_be_free())
	assert_false(session.is_over)


func test_resume_button_closes_pause() -> void:
	_start_match()
	_press(&"pause")
	(_top_screen() as PauseScreen).resume_button.pressed.emit()
	assert_eq(UI.top(), &"")
	await wait_process_frames(1)
	assert_false(get_tree().paused)


func test_settings_from_pause_stacks_above_and_back_returns_to_pause() -> void:
	_start_match()
	_press(&"pause")
	var pause: PauseScreen = _top_screen() as PauseScreen
	var pause_layer: CanvasLayer = pause.get_parent() as CanvasLayer
	pause.settings_button.grab_focus()
	pause.settings_button.pressed.emit()
	assert_eq(UI.top(), &"settings")
	assert_gte((_top_screen().get_parent() as CanvasLayer).layer, pause_layer.layer)
	assert_false(pause_layer.visible, "pause is hidden under settings")
	assert_eq(pause_layer.process_mode, Node.PROCESS_MODE_DISABLED)
	_press(&"pause")
	assert_eq(UI.top(), &"pause", "Esc closes settings only")
	assert_true(pause_layer.visible)
	assert_true(pause.settings_button.has_focus())
	assert_true(get_tree().paused, "still paused after settings")


func test_game_over_pushes_results_and_main_menu_replaces() -> void:
	var session: GameSession = _start_match()
	session.get_players()[0].take_damage(DamageInfo.create(10000.0, null))
	await wait_until(func() -> bool: return UI.top() == &"results", 2.0, "results pushed")
	assert_eq(UI.top(), &"results")
	assert_true(UI.mouse_should_be_free(), "results free the mouse")
	var results: ResultsScreen = _top_screen() as ResultsScreen
	assert_true(results.main_menu_button.has_focus())
	_press(&"pause")
	assert_eq(UI.top(), &"results", "no pause after game over")
	results.main_menu_button.pressed.emit()
	assert_eq(UI.top(), &"")
	await wait_process_frames(2)
	assert_eq(get_tree().current_scene.scene_file_path, "res://systems/ui/main_menu.tscn")


func test_restart_from_results_leaves_an_empty_stack_and_pause_works_again() -> void:
	var session: GameSession = _start_match()
	session.get_players()[0].take_damage(DamageInfo.create(10000.0, null))
	await wait_until(func() -> bool: return UI.top() == &"results", 2.0, "results pushed")
	(_top_screen() as ResultsScreen).restart_button.pressed.emit()
	assert_eq(UI.top(), &"")
	await wait_process_frames(2)
	var fresh: GameSession = get_tree().current_scene as GameSession
	assert_not_null(fresh, "a new match is running")
	assert_false(is_instance_valid(session), "the old match is gone")
	assert_false(fresh.is_over)
	_press(&"pause")
	assert_eq(UI.top(), &"pause")


func test_a_lone_listen_host_pauses_like_solo() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_server(24716, 2), OK)
	var previous: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = peer
	var pause: PauseScreen = PAUSE.instantiate() as PauseScreen
	add_child(pause)
	assert_true(get_tree().paused, "nobody else is in the world, so pause freezes it")
	assert_false(pause.banner.visible)
	pause.free()
	assert_false(get_tree().paused)
	peer.close()
	multiplayer.multiplayer_peer = previous


func test_a_friend_joining_unfreezes_an_open_pause_and_it_stays_unfrozen() -> void:
	var pause: PauseScreen = PAUSE.instantiate() as PauseScreen
	add_child(pause)
	assert_true(get_tree().paused)
	Net.coop_changed.emit(true)
	assert_false(get_tree().paused, "the joiner's world must run")
	assert_true(pause.banner.visible, "the banner says the match goes on")
	Net.coop_changed.emit(false)
	assert_false(get_tree().paused, "the last friend leaving does not freeze an open pause again")
	pause.free()
	assert_false(get_tree().paused)


func test_solo_pause_freezes_the_game_and_hides_the_banner() -> void:
	var pause: PauseScreen = PAUSE.instantiate() as PauseScreen
	add_child(pause)
	assert_true(get_tree().paused)
	assert_false(pause.banner.visible)
	pause.free()
	assert_false(get_tree().paused, "closing pause unfreezes")


func test_a_lone_listen_host_match_ends_like_solo_and_restart_keeps_the_port() -> void:
	assert_eq(Net.host(24717, 2), OK)
	var session: GameSession = _start_match()
	session.get_players()[0].take_damage(DamageInfo.create(10000.0, null))
	await wait_until(func() -> bool: return UI.top() == &"results", 2.0, "results pushed")
	assert_true(session.get_players()[0].is_dead, "solo rule: no bleed-out without friends")
	assert_ne(session.level.process_mode, Node.PROCESS_MODE_DISABLED, "the level is not frozen at match end")
	assert_eq((_top_screen() as ResultsScreen).restart_button.text, "Restart")
	(_top_screen() as ResultsScreen).restart_button.pressed.emit()
	await wait_process_frames(2)
	var fresh: GameSession = get_tree().current_scene as GameSession
	assert_not_null(fresh, "Restart alone plays the match again")
	assert_ne(fresh, session)
	assert_true(Net.is_online(), "the world's port stays open through the restart")
	assert_false(Net.changing_place, "the new match took the open port over")
	Net.leave()

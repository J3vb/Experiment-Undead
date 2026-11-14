## Exercises the registry, console input and commands in a real headless session.
extends GutTest

const CONSOLE: PackedScene = preload("res://systems/debug/debug_console.tscn")
const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var console: CanvasLayer
var received: PackedStringArray = []


func before_each() -> void:
	console = CONSOLE.instantiate() as CanvasLayer
	add_child_autofree(console)


func after_each() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func _record(args: PackedStringArray) -> void:
	received = args


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func test_register_and_run_with_string_arguments() -> void:
	console.register_command(&"record", _record, "record strings")
	console.run_command("  record   12  zombie_walker  ")
	assert_eq(received, PackedStringArray(["12", "zombie_walker"]))


func test_unknown_command_prints_error() -> void:
	console.run_command("missing_command")
	assert_string_contains(console.output.get_parsed_text(), "Error: unknown command 'missing_command'")


func test_history_restores_draft_and_stays_in_bounds() -> void:
	console.run_command("help")
	console.run_command("clear")
	console._set_open(true)
	console.input.text = "unfinished"
	console._input(_key(KEY_UP))
	assert_eq(console.input.text, "clear")
	console._input(_key(KEY_UP))
	console._input(_key(KEY_UP))
	assert_eq(console.input.text, "help")
	console._input(_key(KEY_DOWN))
	console._input(_key(KEY_DOWN))
	console._input(_key(KEY_DOWN))
	assert_eq(console.input.text, "unfinished")
	console._set_open(false)


func test_physical_backtick_toggles_with_focused_input() -> void:
	console._unhandled_input(_key(KEY_QUOTELEFT))
	assert_true(console.panel.visible)
	assert_true(console.input.has_focus())
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	console._input(_key(KEY_QUOTELEFT))
	assert_false(console.panel.visible)


func test_blank_command_and_invalid_arguments_do_not_change_game() -> void:
	console.run_command("   ")
	assert_eq(console.history.size(), 0)
	for line: String in ["give_points nope", "set_round 0", "spawn unknown", "spawn zombie_walker -1"]:
		console.run_command(line)
	assert_eq(console.output.get_parsed_text().count("Error:"), 4)
	console.run_command("timescale 0")
	assert_eq(Engine.time_scale, 1.0)


func test_mutating_commands_reject_non_authority() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", 65534), OK)
	multiplayer.multiplayer_peer = peer
	assert_false(Net.is_authority())
	for line: String in [
		"give_points 5", "set_round 2", "skip_round", "spawn zombie_walker", "kill_all", "timescale 2"
	]:
		console.run_command(line)
	assert_eq(console.output.get_parsed_text().count("requires authority"), 6)
	assert_eq(Engine.time_scale, 1.0)
	multiplayer.multiplayer_peer = null
	peer.close()


func test_give_points_spawn_round_kills_and_seed_in_session() -> void:
	var session: GameSession = SESSION.instantiate() as GameSession
	session.rng_seed = 1234
	var rules: WaveRules = session.wave_rules.duplicate(true) as WaveRules
	rules.first_round_delay = 1000.0
	session.wave_rules = rules
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 10.0, "navigation ready")
	session.director.stop()
	var debug: CanvasLayer = session.get_node("DebugConsole") as CanvasLayer
	var overlay: CanvasLayer = session.get_node("DebugOverlay") as CanvasLayer
	overlay._input(_key(KEY_F3))
	assert_true(overlay._label.visible)
	assert_string_contains(overlay._label.text, "Physics ticks:")
	assert_eq(overlay._timer.wait_time, 0.25)
	assert_true(overlay._timer.ignore_time_scale)
	overlay._input(_key(KEY_F3))
	assert_false(overlay._label.visible)
	assert_true(overlay._timer.is_stopped())
	var player: Player = session.get_players()[0]
	var points: int = player.wallet.points
	debug.run_command("give_points 250")
	assert_eq(player.wallet.points, points + 250)
	debug.run_command("set_round 5")
	assert_eq(session.director.round_number, 5)
	session.director.stop()
	debug.run_command("spawn zombie_walker 2")
	assert_eq(session.spawner.alive_count(), 2)
	debug.run_command("kill_all")
	assert_eq(session.spawner.alive_count(), 0)
	debug.run_command("spawn zombie_walker")
	assert_eq(session.spawner.alive_count(), 1)
	debug.run_command("skip_round")
	assert_eq(session.spawner.alive_count(), 0)
	debug.run_command("seed")
	assert_string_contains(debug.output.get_parsed_text(), "RNG seed: 1234")
	debug._set_open(true)
	assert_false(player.input_enabled)
	assert_false(player.local_input.enabled)
	debug._set_open(false)
	assert_true(player.input_enabled)
	debug.run_command("timescale 0.5")
	assert_eq(Engine.time_scale, 0.5)


func test_revival_while_console_open_keeps_controls_suppressed_then_restores() -> void:
	var session: GameSession = SESSION.instantiate() as GameSession
	session.rng_seed = 1234
	add_child_autofree(session)
	session.director.stop()
	var player: Player = session.get_players()[0]
	var debug: CanvasLayer = session.get_node("DebugConsole") as CanvasLayer
	player.add_serum(Content.get_item(&"serums", &"second_wind") as SerumData)
	player.second_wind_time = 0.05
	player.take_damage(DamageInfo.create(player.health.current, null))
	assert_true(player.is_downed)
	debug._set_open(true)
	await wait_for_signal(Events.player_revived, 2.0)
	assert_true(player.is_alive())
	assert_false(player.input_enabled, "revival cannot enable movement while typing")
	assert_false(player.local_input.enabled)
	debug._set_open(false)
	assert_true(player.input_enabled, "revived player regains controls on close")

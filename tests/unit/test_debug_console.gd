## Registry, input history and tuning commands against a real headless match.
extends GutTest

const CONSOLE: PackedScene = preload("res://systems/debug/debug_console.tscn")
const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var console: CanvasLayer
var received: PackedStringArray = []


func before_each() -> void:
	console = CONSOLE.instantiate()
	add_child_autofree(console)


func after_each() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func _record(args: PackedStringArray) -> void:
	received = args


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	return event


func test_register_run_and_split_arguments() -> void:
	console.register_command(&"record", _record, "record strings")
	console.run_command("  record   12 zombie_walker  ")
	assert_eq(received, PackedStringArray(["12", "zombie_walker"]))
	console.run_command("record")
	assert_true(received.is_empty())


func test_unknown_command_prints_error() -> void:
	console.run_command("missing")
	assert_string_contains(console.log_output.get_parsed_text(), "Error: unknown command 'missing'")


func test_history_preserves_draft_and_bounds() -> void:
	console.run_command("help")
	console.run_command("seedless")
	console.command_input.text = "draft"
	console._on_input_gui(_key(KEY_UP))
	assert_eq(console.command_input.text, "seedless")
	console._on_input_gui(_key(KEY_UP))
	console._on_input_gui(_key(KEY_UP))
	assert_eq(console.command_input.text, "help")
	console._on_input_gui(_key(KEY_DOWN))
	console._on_input_gui(_key(KEY_DOWN))
	assert_eq(console.command_input.text, "draft")


func test_toggle_uses_physical_key_and_restores_mouse() -> void:
	var original: Input.MouseMode = Input.mouse_mode
	var event: InputEventKey = _key(KEY_QUOTELEFT)
	event.keycode = KEY_A
	console._unhandled_input(event)
	assert_true(console.panel.visible)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	console._on_input_gui(event)
	assert_false(console.panel.visible)
	assert_eq(Input.mouse_mode, original)


func test_game_commands_in_headless_session() -> void:
	var session: GameSession = SESSION.instantiate() as GameSession
	session.rng_seed = 1234
	session.wave_rules = session.wave_rules.duplicate(true) as WaveRules
	session.wave_rules.first_round_delay = 1000.0
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 10.0, "navmesh baked")
	var debug: CanvasLayer = session.get_node("DebugConsole") as CanvasLayer
	var player: Player = session.get_players()[0]
	var before: int = player.wallet.points
	debug.run_command("give_points 123")
	assert_eq(player.wallet.points, before + 123)
	debug.run_command("give_points nope")
	assert_eq(player.wallet.points, before + 123)
	debug.run_command("spawn zombie_walker 2")
	assert_eq(session.spawner.alive_count(), 2)
	debug.run_command("spawn missing")
	assert_eq(session.spawner.alive_count(), 2)
	debug.run_command("kill_all")
	assert_eq(session.spawner.alive_count(), 0)
	debug.run_command("set_round 8")
	assert_eq(session.director.round_number, 8)
	debug.run_command("seed")
	assert_string_contains(debug.log_output.get_parsed_text(), "1234")
	debug._set_open(true)
	assert_false(player.input_enabled)
	debug._set_open(false)
	assert_true(player.input_enabled)
	debug._set_open(true)
	player.health.take_damage(DamageInfo.create(10000.0, null))
	debug._set_open(false)
	assert_false(player.input_enabled, "closing must not restore a dead player input")
	_check_revive_input(debug, player)
	_check_overlay(session)
	debug.run_command("timescale 0.5")
	assert_eq(Engine.time_scale, 0.5)
	debug.run_command("timescale 0")
	assert_eq(Engine.time_scale, 0.5)


func _check_overlay(session: GameSession) -> void:
	var overlay: CanvasLayer = session.get_node("DebugOverlay") as CanvasLayer
	overlay._input(_key(KEY_F3))
	assert_true(overlay._label.visible)
	assert_false(overlay._timer.is_stopped())
	assert_eq(overlay._timer.wait_time, 0.25)
	assert_string_contains(overlay._label.text, "Enemies alive: 0")
	overlay._input(_key(KEY_F3))
	assert_false(overlay._label.visible)
	assert_true(overlay._timer.is_stopped())


func test_submitted_command_waits_for_physics() -> void:
	console.register_command(&"record", _record, "record strings")
	console.command_input.text_submitted.emit("record queued")
	assert_true(received.is_empty())
	await wait_physics_frames(2)
	assert_eq(received, PackedStringArray(["queued"]))


func test_open_console_blocks_outside_clicks() -> void:
	console._set_open(true)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = get_viewport().get_visible_rect().size - Vector2(20, 20)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_viewport().push_input(click, true)
	assert_true(get_viewport().is_input_handled(), "backdrop consumes clicks below the panel")
	console._set_open(false)


func test_game_commands_require_authority() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", 19999), OK)
	var previous: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = peer
	var denied: bool = not Net.is_authority()
	for line: String in [
		"give_points 10", "set_round 2", "spawn zombie_walker", "kill_all", "skip_round", "timescale 2"
	]:
		console.run_command(line)
	multiplayer.multiplayer_peer = previous
	peer.close()
	assert_true(denied)
	assert_eq(console.log_output.get_parsed_text().count("requires authority (host/server)"), 6)


func _check_revive_input(debug: CanvasLayer, player: Player) -> void:
	player.health.reset(player.health.max_health)
	player.input_enabled = false
	debug._set_open(true)
	player.input_enabled = true
	debug._set_open(false)
	assert_true(player.input_enabled, "revival just before closing must restore input")
	debug._set_open(true)
	player.input_enabled = true
	debug._physics_process(1.0 / 60.0)
	assert_false(player.input_enabled, "revival must not allow gameplay input while typing")
	debug._set_open(false)
	assert_true(player.input_enabled, "revived player regains input when closing")


func test_real_revival_keeps_console_input_suppressed() -> void:
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
	assert_false(player.input_enabled, "revival signal must suppress input immediately")
	assert_false(player.local_input.enabled)
	debug._set_open(false)
	assert_true(player.input_enabled)
	assert_true(player.local_input.enabled)

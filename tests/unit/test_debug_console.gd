## Exercises the debug console registry and real session commands.
extends GutTest

const CONSOLE: PackedScene = preload("res://systems/debug/debug_console.tscn")
const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var console: DebugConsole
var received: PackedStringArray = []


func before_each() -> void:
	console = CONSOLE.instantiate() as DebugConsole
	add_child_autofree(console)


func _receive(args: PackedStringArray) -> void:
	received = args


func test_register_run_and_split_arguments() -> void:
	console.register_command(&"example", _receive, "test command")
	console.run_command("example  first   second")
	await wait_physics_frames(2)
	assert_eq(received, PackedStringArray(["first", "second"]))


func test_unknown_command_prints_error() -> void:
	console.run_command("no_such_command")
	await wait_physics_frames(2)
	assert_string_contains(console.output.get_parsed_text(), "Error: unknown command 'no_such_command'")


func test_history_moves_up_and_down() -> void:
	console.run_command("first")
	console.run_command("second")
	console._show_history(-1)
	assert_eq(console.input.text, "second")
	console._show_history(-1)
	assert_eq(console.input.text, "first")
	console._show_history(1)
	assert_eq(console.input.text, "second")
	console._show_history(1)
	assert_eq(console.input.text, "")


func test_spawn_in_game_session() -> void:
	var session: GameSession = SESSION.instantiate() as GameSession
	session.rng_seed = 1234
	var rules: WaveRules = session.wave_rules.duplicate(true) as WaveRules
	rules.first_round_delay = 999.0
	session.wave_rules = rules
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 10.0, "navmesh baked")
	var game_console: DebugConsole = session.get_node("DebugConsole") as DebugConsole
	var before: int = session.spawner.alive_count()
	game_console.run_command("spawn zombie_walker 2")
	await wait_physics_frames(2)
	assert_eq(session.spawner.alive_count(), before + 2)
	game_console.run_command("kill_all")
	await wait_physics_frames(2)
	assert_eq(session.spawner.alive_count(), 0)


func test_round_and_overlay_in_game_session() -> void:
	var session: GameSession = SESSION.instantiate() as GameSession
	session.rng_seed = 1234
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 10.0, "navmesh baked")
	var game_console: DebugConsole = session.get_node("DebugConsole") as DebugConsole
	game_console.run_command("set_round 5")
	await wait_physics_frames(2)
	assert_eq(session.director.round_number, 5)
	var overlay: CanvasLayer = session.get_node("DebugOverlay") as CanvasLayer
	var label: Label = overlay.get_child(0) as Label
	assert_false(label.visible)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_F3
	key.pressed = true
	overlay._unhandled_input(key)
	assert_true(label.visible)

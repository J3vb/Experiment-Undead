## In-game command console for development builds.
class_name DebugConsole
extends CanvasLayer

var commands: Dictionary[StringName, Dictionary] = {}
var history: Array[String] = []
var history_index: int = 0
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var pending: Array[String] = []

@onready var panel: Control = $Panel
@onready var output: RichTextLabel = $Panel/Layout/Log
@onready var input: LineEdit = $Panel/Layout/Input
@onready var session: GameSession = get_parent() as GameSession


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	panel.hide()
	input.text_submitted.connect(run_command)
	input.gui_input.connect(_on_input_event)
	register_command(&"help", _help, "List commands")
	register_command(&"clear", _clear, "Clear the log")
	register_command(&"set_round", _set_round, "set_round <n>")
	register_command(&"skip_round", _kill_all, "Kill all alive enemies")
	register_command(&"spawn", _spawn, "spawn <enemy_id> [count]")
	register_command(&"kill_all", _kill_all, "Kill all alive enemies")
	register_command(&"timescale", _timescale, "timescale <x>")
	register_command(&"seed", _seed, "Print the session seed")


func register_command(command_name: StringName, action: Callable, help: String) -> void:
	commands[command_name] = {"action": action, "help": help}


func run_command(line: String) -> void:
	line = line.strip_edges()
	input.clear()
	if line.is_empty():
		return
	history.append(line)
	history_index = history.size()
	write_line("> " + line)
	pending.append(line)


func _physics_process(_delta: float) -> void:
	while not pending.is_empty():
		_execute(pending.pop_front())


func _execute(line: String) -> void:
	var parts: PackedStringArray = line.split(" ", false)
	var command_name: StringName = StringName(parts[0])
	if not commands.has(command_name):
		write_line("Error: unknown command '%s'" % command_name)
		return
	var args: PackedStringArray = parts.slice(1)
	var action: Callable = commands[command_name]["action"]
	action.call(args)


func write_line(message: String) -> void:
	output.add_text(message + "\n")


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_QUOTELEFT:
		_toggle()
		get_viewport().set_input_as_handled()


func _on_input_event(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_QUOTELEFT:
		_toggle()
		input.accept_event()
	elif key.keycode == KEY_UP or key.keycode == KEY_DOWN:
		_show_history(-1 if key.keycode == KEY_UP else 1)
		input.accept_event()


func _show_history(direction: int) -> void:
	history_index = clampi(history_index + direction, 0, history.size())
	input.text = history[history_index] if history_index < history.size() else ""
	input.caret_column = input.text.length()


func _toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		input.grab_focus()
	else:
		input.release_focus()
		Input.mouse_mode = previous_mouse_mode


func _exit_tree() -> void:
	if is_instance_valid(panel) and panel.visible:
		Input.mouse_mode = previous_mouse_mode


func _authority() -> bool:
	if Net.is_authority():
		return true
	write_line("Error: only the authority can change the game")
	return false


func _help(_args: PackedStringArray) -> void:
	var names: Array[StringName] = commands.keys()
	names.sort()
	for command_name: StringName in names:
		write_line("%s: %s" % [command_name, commands[command_name]["help"]])


func _clear(_args: PackedStringArray) -> void:
	output.clear()


func _set_round(args: PackedStringArray) -> void:
	if not _authority():
		return
	if args.size() != 1 or not args[0].is_valid_int() or int(args[0]) < 1:
		write_line("Usage: set_round <positive integer>")
		return
	session.director.skip_to_round(int(args[0]))
	write_line("Round set to %s" % args[0])


func _kill_all(_args: PackedStringArray) -> void:
	if not _authority():
		return
	var count: int = 0
	for node: Node in session.spawner.get_children():
		var zombie: Zombie = node as Zombie
		if zombie and not zombie.health.is_dead:
			zombie.health.take_damage(DamageInfo.create(zombie.health.current + 1.0, null))
			count += 1
	write_line("Killed %d enemies" % count)


func _spawn(args: PackedStringArray) -> void:
	if not _authority():
		return
	if args.is_empty() or args.size() > 2:
		write_line("Usage: spawn <enemy_id> [count]")
		return
	var count: int = 1
	if args.size() == 2:
		if not args[1].is_valid_int() or int(args[1]) < 1 or int(args[1]) > 100:
			write_line("Error: count must be between 1 and 100")
			return
		count = int(args[1])
	var id: StringName = StringName(args[0])
	if not Content.ids(&"enemies").has(id):
		write_line("Error: unknown enemy '%s'" % id)
		return
	var data: EnemyData = Content.enemy(id)
	for _i: int in count:
		session.spawner.spawn(data, maxi(session.director.round_number, 1), session.wave_rules)
	write_line("Spawned %d %s" % [count, id])


func _timescale(args: PackedStringArray) -> void:
	if not _authority():
		return
	if args.size() != 1 or not args[0].is_valid_float() or float(args[0]) <= 0.0:
		write_line("Usage: timescale <positive number>")
		return
	Engine.time_scale = float(args[0])
	write_line("Time scale: %s" % args[0])


func _seed(_args: PackedStringArray) -> void:
	write_line("Seed: %d" % session.rng.seed)

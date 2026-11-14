## Session-local command registry and debug-only console for live tuning.
extends CanvasLayer

var commands: Dictionary[StringName, Dictionary] = {}
var history: PackedStringArray = []
var _history_index: int = 0
var _draft: String = ""
var _mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _player_inputs: Dictionary[Player, bool] = {}

@onready var panel: Control = $Panel
@onready var output: RichTextLabel = $Panel/Box/Log
@onready var input: LineEdit = $Panel/Box/Input


func _ready() -> void:
	panel.hide()
	if not OS.is_debug_build():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	Events.player_revived.connect(_on_player_revived)
	input.text_submitted.connect(run_command)
	register_command(&"help", _help, "help: list commands")
	register_command(&"clear", _clear, "clear: clear the log")
	register_command(&"give_points", _give_points, "give_points <n>: give every player points")
	register_command(&"set_round", _set_round, "set_round <n>: start a round")
	register_command(&"skip_round", _kill_all, "skip_round: kill all alive enemies (unspawned enemies remain)")
	register_command(&"spawn", _spawn, "spawn <enemy_id> [count]: spawn enemies")
	register_command(&"kill_all", _kill_all, "kill_all: kill all alive enemies")
	register_command(&"timescale", _timescale, "timescale <x>: set a positive time scale")
	register_command(&"seed", _seed, "seed: print the session RNG seed")


func register_command(name: StringName, callable: Callable, help: String) -> void:
	commands[name] = {"callable": callable, "help": help}


func run_command(line: String) -> void:
	if not OS.is_debug_build():
		return
	var parts: PackedStringArray = line.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	history.append(line)
	_history_index = history.size()
	_draft = ""
	input.clear()
	write_line("> " + line)
	var name: StringName = StringName(parts[0])
	parts.remove_at(0)
	if not commands.has(name):
		write_line("Error: unknown command '%s'. Try help." % name)
		return
	var callable: Callable = commands[name]["callable"]
	callable.call(parts)


func write_line(message: String) -> void:
	output.append_text(message + "\n")


func _input(event: InputEvent) -> void:
	# Focused LineEdit consumes keys before _unhandled_input; forward console keys.
	if panel.visible and event is InputEventKey:
		if event.physical_keycode in [KEY_QUOTELEFT, KEY_UP, KEY_DOWN]:
			_unhandled_input(event)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.physical_keycode == KEY_QUOTELEFT:
			_set_open(not panel.visible)
			get_viewport().set_input_as_handled()
		elif panel.visible and key.physical_keycode in [KEY_UP, KEY_DOWN]:
			_recall(-1 if key.physical_keycode == KEY_UP else 1)
			get_viewport().set_input_as_handled()
	if panel.visible:
		get_viewport().set_input_as_handled()


func _set_open(value: bool) -> void:
	panel.visible = value
	if value:
		_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		for node: Node in get_tree().get_nodes_in_group(&"players"):
			var player: Player = node as Player
			_player_inputs[player] = player.input_enabled
			player.input_enabled = false
			player.local_input.enabled = false
		input.grab_focus()
	else:
		input.release_focus()
		Input.mouse_mode = _mouse_mode
		for player: Player in _player_inputs:
			if is_instance_valid(player):
				player.input_enabled = _player_inputs[player] and player.is_alive()
				player.local_input.enabled = player.input_enabled
		_player_inputs.clear()


func _on_player_revived(player: Player) -> void:
	if panel.visible and _player_inputs.has(player):
		_player_inputs[player] = true
		player.input_enabled = false
		player.local_input.enabled = false


func _recall(direction: int) -> void:
	if _history_index == history.size():
		_draft = input.text
	_history_index = clampi(_history_index + direction, 0, history.size())
	input.text = _draft if _history_index == history.size() else history[_history_index]
	input.caret_column = input.text.length()


func _authority() -> bool:
	if Net.is_authority():
		return true
	write_line("Error: this command requires authority (host/server only).")
	return false


func _session() -> GameSession:
	return get_parent() as GameSession


func _help(_args: PackedStringArray) -> void:
	for entry: Dictionary in commands.values():
		write_line(entry["help"])


func _clear(_args: PackedStringArray) -> void:
	output.clear()


func _give_points(args: PackedStringArray) -> void:
	if not _authority():
		return
	if args.size() != 1 or not args[0].is_valid_int():
		write_line("Error: usage: give_points <integer>")
		return
	for player: Player in _session().get_players():
		player.wallet.add(args[0].to_int())
	write_line("Gave %s points to every player." % args[0])


func _set_round(args: PackedStringArray) -> void:
	if not _authority():
		return
	if args.size() != 1 or not args[0].is_valid_int() or args[0].to_int() < 1:
		write_line("Error: usage: set_round <positive integer>")
		return
	_session().director.skip_to_round(args[0].to_int())
	write_line("Started round %s." % args[0])


func _spawn(args: PackedStringArray) -> void:
	if not _authority():
		return
	if args.size() < 1 or args.size() > 2:
		write_line("Error: usage: spawn <enemy_id> [positive count]")
		return
	if args.size() == 2 and (not args[1].is_valid_int() or args[1].to_int() < 1):
		write_line("Error: count must be a positive integer.")
		return
	var id: StringName = StringName(args[0])
	if not Content.ids(&"enemies").has(id):
		write_line("Error: unknown enemy '%s'." % id)
		return
	var count: int = args[1].to_int() if args.size() == 2 else 1
	var session: GameSession = _session()
	for i: int in range(count):
		session.spawner.spawn(Content.enemy(id), maxi(session.director.round_number, 1), session.wave_rules)
	write_line("Spawned %d %s." % [count, id])


func _kill_all(_args: PackedStringArray) -> void:
	if not _authority():
		return
	var count: int = 0
	for node: Node in _session().spawner.get_children():
		var zombie: Zombie = node as Zombie
		if zombie and not zombie.health.is_dead:
			zombie.health.take_damage(DamageInfo.create(zombie.health.current, null))
			count += 1
	write_line("Killed %d enemies." % count)


func _timescale(args: PackedStringArray) -> void:
	if not _authority():
		return
	if args.size() != 1 or not args[0].is_valid_float():
		write_line("Error: usage: timescale <positive number>")
		return
	var value: float = args[0].to_float()
	if not is_finite(value) or value <= 0.0:
		write_line("Error: time scale must be finite and positive.")
		return
	Engine.set_time_scale(value)
	write_line("Time scale: %s" % value)


func _seed(_args: PackedStringArray) -> void:
	write_line("RNG seed: %d" % _session().rng.seed)

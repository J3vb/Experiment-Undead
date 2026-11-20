## Debug-only command registry and tuning console owned by the match.
class_name DebugConsole
extends CanvasLayer

var commands: Dictionary[StringName, Dictionary] = {}
var history: PackedStringArray = []
var _history_index: int = 0
var _draft: String = ""
var _pending: PackedStringArray = []
var _player_inputs: Dictionary[Player, bool] = {}

@onready var backdrop: Control = $Backdrop
@onready var panel: PanelContainer = $Panel
@onready var log_output: RichTextLabel = $Panel/Rows/Log
@onready var command_input: LineEdit = $Panel/Rows/Input


func _ready() -> void:
	panel.hide()
	if not OS.is_debug_build():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	Events.player_revived.connect(_on_player_revived)
	command_input.text_submitted.connect(func(line: String) -> void: _pending.append(line))
	command_input.gui_input.connect(_on_input_gui)
	register_command(&"help", _help, "help: list commands")
	register_command(&"clear", func(_args: PackedStringArray) -> void: log_output.clear(), "clear: erase log")
	register_command(&"seed", _seed, "seed: print the match RNG seed")
	for name: StringName in [
		&"give_points", &"set_round", &"skip_round", &"spawn", &"kill_all", &"timescale", &"blackout"
	]:
		register_command(name, _change_game.bind(name), str(name) + _usage(name))
	register_command(&"blackout", _blackout, "blackout on|off: lights out on every peer")


func _physics_process(_delta: float) -> void:
	if panel.visible:
		for player: Player in _player_inputs:
			if is_instance_valid(player) and player.input_enabled:
				_player_inputs[player] = true
				player.input_enabled = false
	while not _pending.is_empty():
		run_command(_pending[0])
		_pending.remove_at(0)


func register_command(name: StringName, callable: Callable, help: String) -> void:
	commands[name] = {"callable": callable, "help": help}


## Callbacks receive one PackedStringArray; each command parses its own strings.
func run_command(line: String) -> void:
	if not OS.is_debug_build():
		return
	var words: PackedStringArray = line.strip_edges().split(" ", false)
	if words.is_empty():
		return
	history.append(line)
	_history_index = history.size()
	_draft = ""
	command_input.clear()
	write_line("> " + line)
	var name: StringName = StringName(words[0])
	if not commands.has(name):
		write_line("Error: unknown command '%s'. Use help." % name)
		return
	var callback: Callable = commands[name]["callable"]
	callback.call(words.slice(1))


func write_line(message: String) -> void:
	log_output.add_text(message + "\n")


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_QUOTELEFT:
		_set_open(not panel.visible)
		get_viewport().set_input_as_handled()
	if panel.visible:
		get_viewport().set_input_as_handled()


func _on_input_gui(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.physical_keycode == KEY_QUOTELEFT:
		_unhandled_input(event)
		command_input.accept_event()
	elif key.keycode == KEY_UP or key.keycode == KEY_DOWN:
		if _history_index == history.size():
			_draft = command_input.text
		_history_index = clampi(_history_index + (-1 if key.keycode == KEY_UP else 1), 0, history.size())
		command_input.text = history[_history_index] if _history_index < history.size() else _draft
		command_input.caret_column = command_input.text.length()
		command_input.accept_event()


func _set_open(value: bool) -> void:
	panel.visible = value
	backdrop.visible = value
	UI.hold_mouse(self, value)
	if value:
		for node: Node in get_tree().get_nodes_in_group(&"players"):
			var player: Player = node as Player
			_player_inputs[player] = player.input_enabled
			player.input_enabled = false
			player.local_input.enabled = false
		command_input.grab_focus()
	else:
		command_input.release_focus()
		for player: Player in _player_inputs:
			if is_instance_valid(player):
				player.input_enabled = (_player_inputs[player] or player.input_enabled) and player.is_alive()
				player.local_input.enabled = player.input_enabled
		_player_inputs.clear()


func _on_player_revived(player: Player) -> void:
	if panel.visible and _player_inputs.has(player):
		_player_inputs[player] = true
		player.input_enabled = false
		player.local_input.enabled = false


func _exit_tree() -> void:
	if is_instance_valid(panel) and panel.visible:
		_set_open(false)


func _help(_args: PackedStringArray) -> void:
	for name: StringName in commands:
		write_line(commands[name]["help"])


func _seed(_args: PackedStringArray) -> void:
	var session: GameSession = get_parent() as GameSession
	write_line(str(session.rng.seed))


func _usage(name: StringName) -> String:
	match name:
		&"give_points", &"set_round":
			return " <n> (positive integer)"
		&"spawn":
			return " <enemy_id> [count]"
		&"timescale":
			return " <x> (positive finite number)"
	return ": kill all currently alive enemies"


func _change_game(args: PackedStringArray, name: StringName) -> void:
	if not Net.is_authority():
		write_line("Error: %s requires authority (host/server)." % name)
		return
	var session: GameSession = get_parent() as GameSession
	match name:
		&"give_points", &"set_round":
			if not _change_progress(args, name, session):
				return
		&"spawn":
			_spawn(args, session)
			return
		&"kill_all", &"skip_round":
			if not _clear_enemies(args, name, session):
				return
		&"timescale":
			if not _set_timescale(args):
				return
	write_line("OK: " + str(name))


func _blackout(args: PackedStringArray) -> void:
	if args.size() != 1 or args[0] not in ["on", "off"]:
		write_line("Error: usage: blackout on|off")
		return
	if not Net.is_authority():
		write_line("Error: blackout requires authority (host/server).")
		return
	(get_parent() as GameSession).director.set_blackout(args[0] == "on")
	write_line("OK: blackout " + args[0])


func _change_progress(args: PackedStringArray, name: StringName, session: GameSession) -> bool:
	if args.size() != 1 or not args[0].is_valid_int() or args[0].to_int() <= 0:
		write_line("Error: usage: " + str(name) + _usage(name))
		return false
	if name == &"give_points":
		for player: Player in session.get_players():
			player.wallet.add(args[0].to_int())
	else:
		session.director.skip_to_round(args[0].to_int())
	return true


func _clear_enemies(args: PackedStringArray, name: StringName, session: GameSession) -> bool:
	if not args.is_empty():
		write_line("Error: usage: " + str(name))
		return false
	for child: Node in session.spawner.get_children():
		var zombie: Zombie = child as Zombie
		if zombie and not zombie.health.is_dead:
			zombie.health.take_damage(DamageInfo.create(zombie.health.current, null))
	return true


func _set_timescale(args: PackedStringArray) -> bool:
	if args.size() != 1 or not args[0].is_valid_float():
		write_line("Error: usage: timescale" + _usage(&"timescale"))
		return false
	var scale: float = args[0].to_float()
	if not is_finite(scale) or scale <= 0.0:
		write_line("Error: timescale must be positive and finite.")
		return false
	Engine.time_scale = scale
	return true


func _spawn(args: PackedStringArray, session: GameSession) -> void:
	if args.is_empty() or args.size() > 2:
		write_line("Error: usage: spawn" + _usage(&"spawn"))
		return
	var count: int = 1
	if args.size() == 2:
		if not args[1].is_valid_int() or args[1].to_int() <= 0:
			write_line("Error: count must be a positive integer.")
			return
		count = args[1].to_int()
	var id: StringName = StringName(args[0])
	if not Content.has(&"enemies", id):
		write_line("Error: unknown enemy '%s'." % id)
		return
	var enemy: EnemyData = Content.enemy(id)
	for index: int in range(count):
		session.spawner.spawn(enemy, maxi(session.director.round_number, 1), session.wave_rules)
	write_line("OK: spawned %d %s" % [count, id])

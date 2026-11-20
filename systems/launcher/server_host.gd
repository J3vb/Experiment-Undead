## Starts, watches and stops a dedicated server run by the game build itself, for the launcher's
## Host a server panel. Port and max players are saved under [server] in user://launcher.cfg.
class_name ServerHost
extends Node

signal changed

const STOP_FILE: String = "user://launcher/server.stop"
const CONFIG: String = "user://launcher.cfg"

var port: int = Net.DEFAULT_PORT
var max_players: int = Net.MAX_PLAYERS
## Version folder name, or the root copy's version, of the running server.
var version: String = ""
var _pid: int = -1


func _ready() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG)
	port = clampi(int(config.get_value("server", "port", Net.DEFAULT_PORT)), 1, 65535)
	max_players = clampi(int(config.get_value("server", "max_players", Net.MAX_PLAYERS)), 1, Net.MAX_PLAYERS)
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_poll)
	add_child(timer)


## Command line for a headless server on this port, at most max players, quitting when stop_file appears.
static func server_args(at_port: int, players: int, stop_file: String) -> PackedStringArray:
	return PackedStringArray(
		[
			"--headless",
			"--",
			"--server",
			"--port=%d" % clampi(at_port, 1, 65535),
			"--max-players=%d" % clampi(players, 1, Net.MAX_PLAYERS),
			"--stop-file=%s" % stop_file,
		]
	)


func is_running() -> bool:
	return _pid > 0 and OS.is_process_running(_pid)


func save(at_port: int, players: int) -> void:
	port = clampi(at_port, 1, 65535)
	max_players = clampi(players, 1, Net.MAX_PLAYERS)
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG)
	config.set_value("server", "port", port)
	config.set_value("server", "max_players", max_players)
	config.save(CONFIG)


## Starts exe as a server. False when it could not start or one is already running.
func start(exe: String, exe_version: String) -> bool:
	if is_running():
		return false
	var stop_file: String = ProjectSettings.globalize_path(STOP_FILE)
	DirAccess.make_dir_recursive_absolute(stop_file.get_base_dir())
	DirAccess.remove_absolute(stop_file)
	_pid = OS.create_process(exe, server_args(port, max_players, stop_file))
	if _pid < 0:
		Log.warn(&"launcher", &"server_start_failed", {"exe": exe})
		return false
	version = exe_version
	Log.info(&"launcher", &"server_started", {"version": version, "port": port, "pid": _pid})
	changed.emit()
	return true


## Asks the server to finish and quit through its stop file.
func stop() -> void:
	if not is_running():
		return
	var file: FileAccess = FileAccess.open(STOP_FILE, FileAccess.WRITE)
	if file:
		file.store_string("stop")
	Log.info(&"launcher", &"server_stop_requested", {"pid": _pid})


func _poll() -> void:
	if _pid > 0 and not OS.is_process_running(_pid):
		Log.info(&"launcher", &"server_exited", {"pid": _pid})
		_pid = -1
		version = ""
		changed.emit()

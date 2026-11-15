## Entry point of the dedicated server build (main scene for the
## dedicated_server feature). Opens the ENet port and runs one match that
## players join. The match sits at /root/GameSession like on clients.
class_name DedicatedServer
extends Node

const MATCH_SCENE: PackedScene = preload("res://systems/game/game_session.tscn")

var port: int = Net.DEFAULT_PORT
var max_players: int = Net.MAX_PLAYERS
var session: GameSession
## Godot does not catch SIGTERM, so the Docker entrypoint creates this file
## on "docker stop" and the server quits cleanly when it sees it.
var stop_file: String = ""


func _ready() -> void:
	port = read_int_setting("port", "EU_PORT", Net.DEFAULT_PORT)
	max_players = clampi(read_int_setting("max-players", "EU_MAX_PLAYERS", Net.MAX_PLAYERS), 1, Net.MAX_PLAYERS)
	var err: Error = Net.host(port, max_players)
	if err != OK:
		push_error("Could not open UDP port %d: %s" % [port, error_string(err)])
		get_tree().quit(1)
		return
	multiplayer.peer_connected.connect(func(id: int) -> void: print("Player connected: %d" % id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: print("Player left: %d" % id))
	session = MATCH_SCENE.instantiate() as GameSession
	session.has_local_player = false
	session.profile_id = &""
	get_tree().root.add_child.call_deferred(session)
	stop_file = OS.get_environment("EU_STOP_FILE")
	if stop_file != "":
		var timer: Timer = Timer.new()
		timer.wait_time = 0.5
		timer.autostart = true
		timer.timeout.connect(_check_stop_file)
		add_child(timer)
	var info: Array = [port, max_players, Build.display_version(), Build.PROTOCOL_VERSION]
	print("Server ready on UDP port %d (max %d players, %s, protocol %d)" % info)
	var ready_file: String = OS.get_environment("EU_READY_FILE")
	if ready_file != "":
		var marker: FileAccess = FileAccess.open(ready_file, FileAccess.WRITE)
		if marker:
			marker.store_string(str(port))


func _exit_tree() -> void:
	if is_instance_valid(session):
		session.queue_free()
	Net.leave()
	print("Server stopped")


## Command line (--port=7777, after "--") wins over the environment variable.
static func read_int_setting(arg_name: String, env_name: String, fallback: int) -> int:
	var prefix: String = "--%s=" % arg_name
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix) and arg.substr(prefix.length()).is_valid_int():
			return arg.substr(prefix.length()).to_int()
	var env: String = OS.get_environment(env_name)
	if env.is_valid_int():
		return env.to_int()
	return fallback


func _check_stop_file() -> void:
	if FileAccess.file_exists(stop_file):
		print("Stop requested")
		session.quit_game()

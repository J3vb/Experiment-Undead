## Entry point of the dedicated server build (main scene for the
## dedicated_server feature). Opens the ENet port and waits for players.
## Placeholder until co-op lands: it accepts connections but runs no match yet.
class_name DedicatedServer
extends Node

const DEFAULT_PORT: int = 7777
const DEFAULT_MAX_PLAYERS: int = 8

var port: int = DEFAULT_PORT
var max_players: int = DEFAULT_MAX_PLAYERS
## Godot does not catch SIGTERM, so the Docker entrypoint creates this file
## on "docker stop" and the server quits cleanly when it sees it.
var stop_file: String = ""

func _ready() -> void:
	port = read_int_setting("port", "EU_PORT", DEFAULT_PORT)
	max_players = clampi(read_int_setting("max-players", "EU_MAX_PLAYERS", DEFAULT_MAX_PLAYERS), 1, DEFAULT_MAX_PLAYERS)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_players)
	if err != OK:
		push_error("Could not open UDP port %d: %s" % [port, error_string(err)])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	stop_file = OS.get_environment("EU_STOP_FILE")
	if stop_file != "":
		var timer: Timer = Timer.new()
		timer.wait_time = 0.5
		timer.autostart = true
		timer.timeout.connect(_check_stop_file)
		add_child(timer)
	print("Server ready on UDP port %d (max %d players, %s, protocol %d)" % [port, max_players, Build.display_version(), Build.PROTOCOL_VERSION])
	var ready_file: String = OS.get_environment("EU_READY_FILE")
	if ready_file != "":
		var marker: FileAccess = FileAccess.open(ready_file, FileAccess.WRITE)
		if marker:
			marker.store_string(str(port))

func _exit_tree() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
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
		get_tree().quit()

func _on_peer_connected(id: int) -> void:
	print("Peer %d connected" % id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer %d disconnected" % id)

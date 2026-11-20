## Entry point of the dedicated server build (main scene for the
## dedicated_server feature). Opens the ENet port and runs one place at a time
## (the hub, then the match the squad deploys to). The session sits at
## /root/GameSession like on clients and is swapped when the place changes.
class_name DedicatedServer
extends Node

## Clients see their results before the order to leave arrives.
const RESULTS_GRACE: float = 1.0
## A squad changing place leaves and rejoins within this; only then is the server really empty.
const EMPTY_GRACE: float = 12.0
## Exit code of a drained server: whoever started it restarts it on the newer version.
const EXIT_UPDATE: int = 3
const CHECK_EVERY: float = 0.5

## Screens id of the first place. Tools and tests that need a match set it before super().
## After a match, or when the last player leaves one, the server goes back here.
var start_place: StringName = DeployVote.HUB
var port: int = Net.DEFAULT_PORT
var max_players: int = Net.MAX_PLAYERS
var session: GameSession
## Godot does not catch SIGTERM, so the Docker entrypoint creates this file
## on "docker stop" and the server quits cleanly when it sees it.
var stop_file: String = ""
## Appears when a newer release is installed: finish the match, then quit with EXIT_UPDATE.
var drain_file: String = ""
var draining: bool = false
var _empty_for: float = 0.0


func _ready() -> void:
	port = read_int_setting("port", "EU_PORT", Net.DEFAULT_PORT)
	max_players = clampi(read_int_setting("max-players", "EU_MAX_PLAYERS", Net.MAX_PLAYERS), 1, Net.MAX_PLAYERS)
	var err: Error = Net.host(port, max_players)
	if err != OK:
		push_error("Could not open UDP port %d: %s" % [port, error_string(err)])
		get_tree().quit(1)
		return
	var shown_name: String = OS.get_environment("EU_SERVER_NAME")
	Net.info.start(port, shown_name if not shown_name.is_empty() else "Dedicated server")
	multiplayer.peer_connected.connect(func(id: int) -> void: print("Player connected: %d" % id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: print("Player left: %d" % id))
	Net.place = start_place
	Net.place_changed.connect(_swap_session, CONNECT_DEFERRED)
	Events.game_over.connect(_on_game_over)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	session = _make_session(start_place)
	get_tree().root.add_child.call_deferred(session)
	stop_file = read_string_setting("stop-file", "EU_STOP_FILE")
	drain_file = read_string_setting("drain-file", "EU_DRAIN_FILE")
	if stop_file != "" or drain_file != "":
		var timer: Timer = Timer.new()
		timer.wait_time = CHECK_EVERY
		timer.autostart = true
		timer.timeout.connect(_check_files)
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


func _make_session(place: StringName) -> GameSession:
	var data: ScreenData = Content.get_item(UI.TYPE, place) as ScreenData
	var fresh: GameSession = (load(data.scene) as PackedScene).instantiate() as GameSession
	fresh.has_local_player = false
	fresh.profile_id = &""
	return fresh


## Clients were already sent away, so the new session starts empty. Old and new
## swap in one call: no client can join between them.
func _swap_session(place: StringName) -> void:
	var old: GameSession = session
	session = _make_session(place)
	if is_instance_valid(old):
		get_tree().root.remove_child(old)
		old.queue_free()
	get_tree().root.add_child(session)


func _on_game_over(_stats: Dictionary) -> void:
	_return_later(&"game_over", RESULTS_GRACE)


func _on_peer_left(_peer_id: int) -> void:
	if multiplayer.get_peers().is_empty():
		_return_later(&"empty", EMPTY_GRACE)


## Back to the start place with a fresh session, unless the place changed meanwhile or
## (for an empty server) someone came back. A server that starts in the match stays.
func _return_later(reason: StringName, delay: float) -> void:
	var old_id: int = session.get_instance_id()
	await get_tree().create_timer(delay).timeout
	if session.get_instance_id() != old_id or Net.place == start_place:
		return
	if reason == &"empty" and not multiplayer.get_peers().is_empty():
		return
	Log.info(&"net", &"match_reset", {"reason": reason, "place": String(start_place)})
	Net.change_place(start_place)


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


## Command line (--stop-file=/path, after "--") wins over the environment variable.
## The launcher passes it this way: OS.create_process cannot set environment variables.
static func read_string_setting(arg_name: String, env_name: String) -> String:
	var prefix: String = "--%s=" % arg_name
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return OS.get_environment(env_name)


func _check_files() -> void:
	if stop_file != "" and FileAccess.file_exists(stop_file):
		print("Stop requested")
		session.quit_game()
		return
	if not draining and drain_file != "" and FileAccess.file_exists(drain_file):
		draining = true
		Log.info(&"server", &"drain_started", {"place": String(Net.place), "players": multiplayer.get_peers().size()})
	if draining and drain_step(CHECK_EVERY, multiplayer.get_peers().size()):
		Log.info(&"server", &"update_restart", {"place": String(Net.place)})
		Net.end_reason = "server_updating"
		session.quit_game(EXIT_UPDATE)


## While draining: a match plays on (rejoins still work); the hub refuses new players and
## sends everyone off with the "updating" notice; an empty server waits EMPTY_GRACE (a squad
## changing place looks empty for a moment). True when the server should quit with EXIT_UPDATE.
func drain_step(delta: float, players: int) -> bool:
	var in_hub: bool = Net.place == DeployVote.HUB
	if is_instance_valid(session) and session.handshake:
		session.handshake.draining = in_hub
	if players > 0:
		_empty_for = 0.0
		return in_hub
	_empty_for += delta
	return _empty_for >= EMPTY_GRACE

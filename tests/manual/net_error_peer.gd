## Small real ENet peer for admission and shutdown integration checks.
extends SceneTree

var _scenario: String = ""
var _port: int = 24654
var _ready_file: String = ""
var _net: Node
var _handshake: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_net = root.get_node("Net")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			_scenario = arg.trim_prefix("--scenario=")
		elif arg.begins_with("--port="):
			_port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--ready="):
			_ready_file = arg.trim_prefix("--ready=")
	if _scenario == "version":
		root.get_node("Build").version = "0.4.1"
	if _scenario == "full":
		var player: Node = Node.new()
		root.add_child(player)
		player.add_to_group(&"players")
	assert(_net.host(_port, 1 if _scenario == "full" else _net.MAX_PLAYERS) == OK)
	if _scenario == "unknown":
		(root.multiplayer as SceneMultiplayer).auth_callback = _refuse_with_unknown_code
	else:
		_add_handshake()
	root.multiplayer.peer_connected.connect(_on_connected)
	var marker: FileAccess = FileAccess.open(_ready_file, FileAccess.WRITE)
	marker.store_string("ready")
	marker.close()
	create_timer(15.0).timeout.connect(func() -> void: quit())


func _add_handshake() -> void:
	_handshake = (load("res://systems/net/handshake.gd") as GDScript).new() as Node
	_handshake.has_local_player = _scenario == "full"
	_handshake.max_players = _net.player_limit
	root.add_child(_handshake)
	if _scenario == "content":
		_handshake.fingerprint = "different-game-content"
	_handshake.setup()


## Plays a newer server: a reason code this build has never heard of, with its own text.
func _refuse_with_unknown_code(peer_id: int, bytes: PackedByteArray) -> void:
	var scene: SceneMultiplayer = root.multiplayer as SceneMultiplayer
	if bytes.get_string_from_utf8().contains("refused_ack"):
		scene.disconnect_peer(peer_id)
		return
	var reply: Dictionary = {
		"t": "refused",
		"reason": 99,
		"server_version": "9.0.0",
		"server_protocol": 99,
		"text": "This server is closed for maintenance.",
		"maintenance_until": "tomorrow",
	}
	scene.send_auth(peer_id, JSON.stringify(reply).to_utf8_buffer())


func _on_connected(peer_id: int) -> void:
	if _scenario == "quit":
		await create_timer(0.2).timeout
		quit()
	elif _scenario == "ended":
		await create_timer(0.2).timeout
		_net.leave()
	elif _scenario == "lost":
		await create_timer(0.2).timeout
		root.multiplayer.multiplayer_peer.disconnect_peer(peer_id)

## Small real ENet peer for admission and shutdown integration checks.
extends SceneTree

var _scenario: String = ""
var _port: int = 24654
var _ready_file: String = ""
var _net: Node


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
	if _scenario == "content":
		_net._fingerprint = "different-game-content"
	root.multiplayer.peer_connected.connect(_on_connected)
	var marker: FileAccess = FileAccess.open(_ready_file, FileAccess.WRITE)
	marker.store_string("ready")
	marker.close()
	create_timer(15.0).timeout.connect(func() -> void: quit())


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

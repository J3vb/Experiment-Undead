extends GutTest

var watch: HealthWatch


func before_each() -> void:
	watch = HealthWatch.new()
	add_child_autofree(watch)
	watch.set_process(false)


func _count(key: String) -> int:
	return Log.event_counts.get(key, 0)


func test_long_frames_warn_once_per_second() -> void:
	var before: int = _count("perf.long_frames")
	for i: int in 12:
		watch.record_frame(0.1)
	assert_eq(_count("perf.long_frames"), before + 1, "12 slow frames in 1.2 s = one grouped warning")
	assert_almost_eq(watch.worst_frame_ms, 100.0, 0.1)
	assert_eq(watch.long_frames, 12)


func test_smooth_frames_do_not_warn() -> void:
	var before: int = _count("perf.long_frames")
	for i: int in 120:
		watch.record_frame(1.0 / 60.0)
	assert_eq(_count("perf.long_frames"), before)


func test_low_fps_warns_after_three_seconds() -> void:
	watch._check_fps = true
	var before: int = _count("perf.low_fps")
	for i: int in 50:
		watch.record_frame(0.04)
	assert_eq(_count("perf.low_fps"), before, "two seconds at 25 fps is not enough")
	for i: int in 50:
		watch.record_frame(0.04)
	assert_eq(_count("perf.low_fps"), before + 1)
	for i: int in 100:
		watch.record_frame(0.04)
	assert_eq(_count("perf.low_fps"), before + 1, "no repeat while it stays low")


func test_round_without_kills_is_stalled() -> void:
	var before: int = _count("waves.round_stalled")
	watch._round_progress(true)
	watch.check_stall(HealthWatch.STALL_SECONDS - 1.0)
	assert_eq(_count("waves.round_stalled"), before)
	watch.check_stall(2.0)
	watch.check_stall(200.0)
	assert_eq(_count("waves.round_stalled"), before + 1, "reported once per round")


func test_sample_has_leak_signals() -> void:
	var data: Dictionary = watch.snapshot()
	for key: String in ["fps", "memory_mb", "objects", "nodes", "orphan_nodes", "enemies"]:
		assert_true(data.has(key), "snapshot has %s" % key)


func test_clients_never_report_a_stalled_round() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	var scene: SceneMultiplayer = SceneMultiplayer.new()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", 24714), OK)
	scene.multiplayer_peer = peer
	get_tree().set_multiplayer(scene, root.get_path())
	var client_watch: HealthWatch = HealthWatch.new()
	root.add_child(client_watch)
	client_watch.set_process(false)
	var before: int = _count("waves.round_stalled")
	client_watch._round_progress(true)
	client_watch.check_stall(HealthWatch.STALL_SECONDS + 10.0)
	assert_eq(_count("waves.round_stalled"), before, "clients get round events but no kill events")
	peer.close()
	get_tree().set_multiplayer(null, root.get_path())

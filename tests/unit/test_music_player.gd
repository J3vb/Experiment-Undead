## Music follows round facts and smooths pressure without changing gameplay.
extends GutTest

const MUSIC: PackedScene = preload("res://systems/audio/music_player.tscn")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
var music: MusicPlayer


func before_each() -> void:
	music = MUSIC.instantiate() as MusicPlayer
	add_child_autofree(music)
	music.set_process(false)


func step_fade(seconds: float) -> void:
	music._fade.pause()
	music._fade.custom_step(seconds)


func test_round_and_intermission_crossfade() -> void:
	Events.intermission_started.emit(1, 10.0)
	step_fade(3.1)
	assert_almost_eq(music.breather.volume_db, -18.0, 0.01)
	Events.round_started.emit(1, 8)
	step_fade(1.5)
	assert_gt(music.combat.volume_linear, 0.0)
	assert_gt(music.breather.volume_linear, 0.0)
	step_fade(1.6)
	assert_almost_eq(music.combat.volume_db, -18.0, 0.01)
	assert_false(music.breather.playing)
	Events.intermission_started.emit(2, 10.0)
	step_fade(3.1)
	assert_false(music.combat.playing)
	assert_almost_eq(music.breather.volume_db, -18.0, 0.01)


func test_pressure_smooths_and_drive_reaches_endpoints() -> void:
	Events.round_started.emit(1, 8)
	music._process(2.0)
	assert_almost_eq(music.intensity, 0.05, 0.001)
	assert_eq(music.stems.get_sync_stream_volume(1), -80.0)
	assert_eq(music.calculate_intensity(10, 8), 1.0)
	music._target_intensity = music.calculate_intensity(10, 8)
	music._sample_time = 10.0
	music._process(0.5)
	assert_almost_eq(music.intensity, 0.3, 0.001)
	music._process(2.0)
	assert_eq(music.stems.get_sync_stream_volume(1), 0.0)
	assert_eq(music.stems.get_sync_stream_volume(0), 0.0)


func test_proximity_counts_living_enemies_in_radius() -> void:
	var player: Player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.camera.make_current()
	var enemy_scene: PackedScene = load("res://systems/enemies/zombie.tscn") as PackedScene
	for index: int in range(10):
		var zombie: Zombie = enemy_scene.instantiate() as Zombie
		add_child_autofree(zombie)
		zombie.process_mode = Node.PROCESS_MODE_DISABLED
		zombie.position = player.position + Vector3(14.0 if index < 8 else 16.0, 0.0, 0.0)
	assert_eq(music._nearby_enemies(), 8)
	Events.round_started.emit(10, 10)
	music._process(2.0)
	assert_eq(music.intensity, 1.0)
	assert_eq(music.stems.get_sync_stream_volume(1), 0.0)
	var enemy: Zombie = get_tree().get_first_node_in_group(&"enemies") as Zombie
	enemy.state = Zombie.State.DEAD
	assert_eq(music._nearby_enemies(), 7)


func test_game_over_fades_both_even_during_transition() -> void:
	Events.intermission_started.emit(1, 10.0)
	step_fade(3.1)
	Events.round_started.emit(10, 8)
	step_fade(1.5)
	Events.game_over.emit({})
	step_fade(1.0)
	assert_gt(music.combat.volume_linear, 0.0)
	assert_gt(music.breather.volume_linear, 0.0)
	step_fade(1.1)
	assert_false(music.combat.playing)
	assert_false(music.breather.playing)
	assert_eq(music.combat.volume_linear, 0.0)
	assert_eq(music.breather.volume_linear, 0.0)

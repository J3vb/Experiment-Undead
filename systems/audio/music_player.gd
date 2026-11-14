## Visual-side round music: synchronized combat stems and a warm intermission loop.
class_name MusicPlayer
extends Node

@export var fade_seconds: float = 3.0
@export var game_over_fade_seconds: float = 2.0
@export var smoothing_seconds: float = 2.0
@export var sample_interval: float = 0.25
@export var round_for_full: float = 10.0
@export var proximity_radius: float = 15.0
@export var enemies_for_full: float = 8.0
@export var drive_start: float = 0.3
@export var drive_full: float = 0.8
@export var music_volume_db: float = -18.0

var intensity: float = 0.0
var _target_intensity: float = 0.0
var _round: int = 0
var _in_round: bool = false
var _sample_time: float = 0.0
var _fade: Tween

@onready var combat: AudioStreamPlayer = $Combat
@onready var breather: AudioStreamPlayer = $Breather
@onready var stems: AudioStreamSynchronized = combat.stream as AudioStreamSynchronized


func _ready() -> void:
	stems.set_sync_stream_volume(1, -80.0)
	Events.round_started.connect(_on_round_started)
	Events.intermission_started.connect(_on_intermission_started)
	Events.game_over.connect(_on_game_over)


func _process(delta: float) -> void:
	if _in_round:
		_sample_time -= delta
		if _sample_time <= 0.0:
			_sample_time = maxf(sample_interval, 0.25)
			_target_intensity = calculate_intensity(_round, _nearby_enemies())
		intensity = move_toward(intensity, _target_intensity, delta / maxf(smoothing_seconds, 0.001))
		var drive_gain: float = clampf(inverse_lerp(drive_start, drive_full, intensity), 0.0, 1.0)
		stems.set_sync_stream_volume(1, linear_to_db(drive_gain) if drive_gain > 0.0 else -80.0)


func calculate_intensity(round_number: int, nearby: int) -> float:
	return (
		0.5 * clampf(float(round_number) / round_for_full, 0.0, 1.0)
		+ 0.5 * clampf(float(nearby) / enemies_for_full, 0.0, 1.0)
	)


func _nearby_enemies() -> int:
	var local_player: Player = null
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: Player = node as Player
		if player and player.camera.is_current():
			local_player = player
			break
	if local_player == null:
		return 0
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var zombie: Zombie = node as Zombie
		if zombie and zombie.state != Zombie.State.DEAD:
			if local_player.global_position.distance_squared_to(zombie.global_position) <= proximity_radius ** 2:
				count += 1
	return count


func _on_round_started(round_number: int, _count: int) -> void:
	_round = round_number
	_in_round = true
	_sample_time = 0.0
	_crossfade(true, false, fade_seconds)


func _on_intermission_started(_next_round: int, _duration: float) -> void:
	_in_round = false
	_crossfade(false, true, fade_seconds)


func _on_game_over(_stats: Dictionary) -> void:
	_in_round = false
	_crossfade(false, false, game_over_fade_seconds)


func _crossfade(rounds: bool, rest: bool, seconds: float) -> void:
	if _fade:
		_fade.kill()
	if rounds and not combat.playing:
		combat.play()
	if rest and not breather.playing:
		breather.play()
	var gain: float = db_to_linear(music_volume_db)
	_fade = create_tween().set_parallel()
	_fade.tween_property(combat, "volume_linear", gain if rounds else 0.0, seconds)
	_fade.tween_property(breather, "volume_linear", gain if rest else 0.0, seconds)
	_fade.chain().tween_callback(_stop_silent.bind(rounds, rest))


func _stop_silent(rounds: bool, rest: bool) -> void:
	if not rounds:
		combat.stop()
	if not rest:
		breather.stop()

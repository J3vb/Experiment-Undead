## Map ambience: a looping room-tone bed per area, crossfaded by where the local
## player stands, plus quiet distant one-shots around them. Sound only.
## Each Area3D child is an area with a "Bed" player; "Default" plays everywhere else.
class_name Ambience
extends Node3D

@export var fade_seconds: float = 1.5
@export var bed_volume_db: float = -16.0
@export var one_shot_min_seconds: float = 8.0
@export var one_shot_max_seconds: float = 25.0
@export var one_shot_distance: Vector2 = Vector2(8.0, 16.0)

var area: Area3D
## Areas the local player overlaps, newest last; doorways overlap two.
var _inside: Array[Area3D] = []
var _beds: Array[AudioStreamPlayer] = []
var _fade: Tween

@onready var default_bed: AudioStreamPlayer = $Default
@onready var one_shot: AudioStreamPlayer3D = $OneShot
@onready var one_shot_timer: Timer = $OneShotTimer


func _ready() -> void:
	_beds.append(default_bed)
	for child: Node in get_children():
		var zone: Area3D = child as Area3D
		if zone == null:
			continue
		zone.collision_layer = 0
		zone.collision_mask = Layers.PLAYER
		zone.body_entered.connect(_on_body_entered.bind(zone))
		zone.body_exited.connect(_on_body_exited.bind(zone))
		_beds.append(zone.get_node("Bed") as AudioStreamPlayer)
	for bed: AudioStreamPlayer in _beds:
		bed.volume_db = target_volume_db(bed)
		bed.play()
	one_shot_timer.timeout.connect(_play_one_shot)
	_restart_timer()


func beds() -> Array[AudioStreamPlayer]:
	return _beds


func active_bed() -> AudioStreamPlayer:
	return area.get_node("Bed") as AudioStreamPlayer if area else default_bed


func target_volume_db(bed: AudioStreamPlayer) -> float:
	return bed_volume_db if bed == active_bed() else -80.0


func enter(zone: Area3D) -> void:
	_inside.erase(zone)
	_inside.append(zone)
	_set_area(zone)


func leave(zone: Area3D) -> void:
	_inside.erase(zone)
	_set_area(_inside.back() if not _inside.is_empty() else null)


func _set_area(zone: Area3D) -> void:
	if zone != area:
		area = zone
		_crossfade()


func _on_body_entered(body: Node3D, zone: Area3D) -> void:
	if _is_local_player(body):
		enter(zone)


func _on_body_exited(body: Node3D, zone: Area3D) -> void:
	if _is_local_player(body):
		leave(zone)


func _is_local_player(body: Node3D) -> bool:
	var player: Player = body as Player
	return player != null and player.camera.current


func _crossfade() -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween().set_parallel()
	for bed: AudioStreamPlayer in _beds:
		_fade.tween_property(bed, "volume_linear", db_to_linear(target_volume_db(bed)), fade_seconds)


func _play_one_shot() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		var angle: float = randf() * TAU  # cosmetic
		var distance: float = randf_range(one_shot_distance.x, one_shot_distance.y)  # cosmetic
		one_shot.global_position = camera.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		one_shot.play()
	_restart_timer()


func _restart_timer() -> void:
	one_shot_timer.start(randf_range(one_shot_min_seconds, one_shot_max_seconds))  # cosmetic

## Map ambience: a looping room-tone bed per area, crossfaded by where the current
## camera is (the local player, or the teammate being spectated), plus quiet distant
## one-shots around it. Sound only. Each Area3D child is an area box with a "Bed"
## player; "Default" plays everywhere else.
class_name Ambience
extends Node3D

@export var fade_seconds: float = 1.5
@export var bed_volume_db: float = -16.0
@export var one_shot_min_seconds: float = 8.0
@export var one_shot_max_seconds: float = 25.0
@export var one_shot_distance: Vector2 = Vector2(8.0, 16.0)
@export var check_interval: float = 0.25

var area: Area3D
var _zones: Array[Area3D] = []
var _half_sizes: Array[Vector3] = []
var _beds: Array[AudioStreamPlayer] = []
var _check_left: float = 0.0
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
		zone.monitoring = false
		zone.collision_layer = 0
		zone.collision_mask = 0
		_zones.append(zone)
		_half_sizes.append(((zone.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size * 0.5)
		_beds.append(zone.get_node("Bed") as AudioStreamPlayer)
	for bed: AudioStreamPlayer in _beds:
		bed.volume_db = target_volume_db(bed)
		bed.play()
	one_shot_timer.timeout.connect(_play_one_shot)
	_restart_timer()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = check_interval
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		set_area(zone_at(camera.global_position))


func beds() -> Array[AudioStreamPlayer]:
	return _beds


func active_bed() -> AudioStreamPlayer:
	return area.get_node("Bed") as AudioStreamPlayer if area else default_bed


func target_volume_db(bed: AudioStreamPlayer) -> float:
	return bed_volume_db if bed == active_bed() else -80.0


## The area box containing a world position, or null.
func zone_at(point: Vector3) -> Area3D:
	for index: int in _zones.size():
		var local: Vector3 = _zones[index].global_transform.affine_inverse() * point
		var half: Vector3 = _half_sizes[index]
		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
			return _zones[index]
	return null


func set_area(zone: Area3D) -> void:
	if zone != area:
		area = zone
		_crossfade()


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

## A torn cable that spits a burst of sparks with a short light flash every few
## seconds, with a crackle if it has a Crackle player. Cosmetic only: timing
## uses randf, so peers see different bursts.
class_name SparkSpot
extends Node3D

const FLASH_SECONDS: float = 0.08

@export var min_interval: float = 3.0
@export var max_interval: float = 9.0

var _next: float = 0.0
var _flash_left: float = 0.0

@onready var particles: GPUParticles3D = $Particles
@onready var flash: OmniLight3D = $Flash
@onready var crackle: AudioStreamPlayer3D = get_node_or_null(^"Crackle") as AudioStreamPlayer3D


func _ready() -> void:
	flash.visible = false
	_schedule()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			flash.visible = false
	_next -= delta
	if _next <= 0.0:
		burst()


func burst() -> void:
	particles.restart()
	flash.visible = true
	_flash_left = FLASH_SECONDS
	if crackle:
		crackle.play()
	_schedule()


## Seconds until the next burst.
func time_to_next() -> float:
	return _next


func _schedule() -> void:
	_next = randf_range(min_interval, max_interval)  # cosmetic

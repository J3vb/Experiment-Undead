## Makes a light flicker and occasionally cut out. Drop on any Light3D.
class_name FlickerLight
extends Node

@export var light: Light3D
@export var min_energy: float = 0.6
@export var max_energy: float = 1.0
@export var flicker_speed: float = 12.0
@export_range(0.0, 1.0) var dropout_chance: float = 0.02

## Energy the flicker swings around; set it when the light changes level.
var base_energy: float = 1.0
var _time: float = 0.0
var _dropout: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()


func _ready() -> void:
	if light == null:
		light = get_parent() as Light3D
	if light:
		base_energy = light.light_energy
	_noise.seed = randi()
	_noise.frequency = 1.0


func _process(delta: float) -> void:
	if light == null:
		return
	_time += delta * flicker_speed
	if _dropout > 0.0:
		_dropout -= delta
		light.light_energy = base_energy * 0.05
		return
	if randf() < dropout_chance * delta * 10.0:
		_dropout = randf_range(0.05, 0.25)
	var n: float = (_noise.get_noise_1d(_time) + 1.0) * 0.5
	light.light_energy = base_energy * lerpf(min_energy, max_energy, n)

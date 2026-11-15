## Reuses the paired procedural albedo/normal setup across the five rough surfaces.
@tool
class_name NoiseMaterial
extends StandardMaterial3D

@export var noise_frequency: float = 0.06:
	set(value):
		noise_frequency = value
		_noise.frequency = value
@export var noise_bump_strength: float = 3.0:
	set(value):
		noise_bump_strength = value
		_normal.bump_strength = value

var _noise: FastNoiseLite = FastNoiseLite.new()
var _normal: NoiseTexture2D = NoiseTexture2D.new()


func _init() -> void:
	_noise.frequency = noise_frequency
	_noise.fractal_octaves = 5
	var albedo: NoiseTexture2D = NoiseTexture2D.new()
	albedo.width = 512
	albedo.height = 512
	albedo.seamless = true
	albedo.noise = _noise
	_normal.width = 512
	_normal.height = 512
	_normal.seamless = true
	_normal.as_normal_map = true
	_normal.bump_strength = noise_bump_strength
	_normal.noise = _noise
	albedo_texture = albedo
	normal_enabled = true
	normal_texture = _normal
	uv1_triplanar = true


func _validate_property(property: Dictionary) -> void:
	if property["name"] in ["albedo_texture", "normal_enabled", "normal_texture", "uv1_triplanar"]:
		property["usage"] = (int(property["usage"]) & ~PROPERTY_USAGE_STORAGE) | PROPERTY_USAGE_READ_ONLY

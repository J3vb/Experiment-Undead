## Recoil pattern for one gun. Each entry is the kick for that shot in
## degrees (x = yaw right, y = pitch up). After the last entry the final
## few shots repeat.
class_name RecoilData
extends Resource

@export var pattern: Array[Vector2] = [Vector2(0.0, 1.0)]
## Random degrees added on top of the pattern, per axis.
@export var random_spread: Vector2 = Vector2(0.25, 0.15)
## How fast the camera spring returns to centre (per second).
@export var recovery_speed: float = 9.0
@export var ads_multiplier: float = 0.6
## Share of the kick that stays (player must pull down).
@export_range(0.0, 1.0) var permanent_ratio: float = 0.35
## Seconds without firing before the pattern starts over.
@export var reset_time: float = 0.3
@export var repeat_last: int = 4

func get_kick(shot_index: int, rng: RandomNumberGenerator) -> Vector2:
	if pattern.is_empty():
		return Vector2.ZERO
	var i: int = shot_index
	if i >= pattern.size():
		var tail: int = clampi(repeat_last, 1, pattern.size())
		i = pattern.size() - tail + (shot_index - pattern.size()) % tail
	var kick: Vector2 = pattern[i]
	kick.x += rng.randf_range(-random_spread.x, random_spread.x)
	kick.y += rng.randf_range(-random_spread.y, random_spread.y)
	return kick

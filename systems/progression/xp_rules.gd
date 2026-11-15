## XP rewards, level thresholds and cumulative skill points. Shared data stays unchanged.
class_name XpRules
extends Resource

@export var headshot_kill_bonus: int = 5
@export var round_clear_xp_per_round: int = 50
@export var level_base: int = 500
@export var level_exponent: float = 1.25
@export var round_to: int = 50
@export var max_level: int = 50
@export var bonus_point_levels: Array[int] = [10, 20, 30, 40, 50]


func xp_to_next(level: int) -> int:
	if level >= max_level:
		return 0
	return int(roundf(level_base * pow(maxi(level, 1), level_exponent) / round_to)) * round_to


func total_xp_for_level(level: int) -> int:
	var total: int = 0
	for current: int in range(1, clampi(level, 1, max_level)):
		total += xp_to_next(current)
	return total


func level_for_total_xp(total: int) -> int:
	var level: int = 1
	var threshold: int = xp_to_next(level)
	while level < max_level and total >= threshold:
		level += 1
		threshold += xp_to_next(level)
	return level


func skill_points_for_level(level: int) -> int:
	var capped: int = clampi(level, 1, max_level)
	var points: int = capped - 1
	for bonus_level: int in bonus_point_levels:
		if bonus_level <= capped:
			points += 1
	return points

## All round scaling in one data file, so balancing never touches code.
class_name WaveRules
extends Resource

@export var enemy_mix: Array[EnemySpawnEntry] = []

@export_group("Timing")
@export var first_round_delay: float = 4.0
@export var intermission_time: float = 10.0
@export var spawn_interval_start: float = 2.0
@export var spawn_interval_min: float = 0.35
@export var spawn_interval_step: float = 0.15

@export_group("Count")
## count = base + linear*(r-1) + quadratic*(r-1)^2, then + extra_per_player
@export var base_count: int = 6
@export var count_linear: float = 3.0
@export var count_quadratic: float = 0.3
@export var extra_per_player: int = 4
@export var max_alive: int = 24
@export var max_alive_per_extra_player: int = 4

@export_group("Scaling")
@export var health_growth_per_round: float = 0.15
@export var speed_growth_per_round: float = 0.04
@export var max_speed_multiplier: float = 1.8
@export var damage_growth_per_round: float = 0.03

@export_group("Spawning")
@export var min_spawn_distance: float = 10.0

func get_enemy_count(round_number: int, players: int = 1) -> int:
	var n: float = float(round_number - 1)
	return base_count + int(round(count_linear * n + count_quadratic * n * n)) + extra_per_player * maxi(players - 1, 0)

func get_max_alive(players: int = 1) -> int:
	return max_alive + max_alive_per_extra_player * maxi(players - 1, 0)

func get_spawn_interval(round_number: int) -> float:
	return maxf(spawn_interval_start - spawn_interval_step * (round_number - 1), spawn_interval_min)

func get_health_multiplier(round_number: int) -> float:
	return 1.0 + health_growth_per_round * (round_number - 1)

func get_speed_multiplier(round_number: int) -> float:
	return minf(1.0 + speed_growth_per_round * (round_number - 1), max_speed_multiplier)

func get_damage_multiplier(round_number: int) -> float:
	return 1.0 + damage_growth_per_round * (round_number - 1)

func pick_enemy(round_number: int, rng: RandomNumberGenerator) -> EnemyData:
	var total: float = 0.0
	for entry: EnemySpawnEntry in enemy_mix:
		total += entry.get_weight(round_number)
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	for entry: EnemySpawnEntry in enemy_mix:
		var w: float = entry.get_weight(round_number)
		if w <= 0.0:
			continue
		roll -= w
		if roll <= 0.0:
			return entry.enemy
	return enemy_mix.back().enemy

## One row of a round's enemy mix.
class_name EnemySpawnEntry
extends Resource

@export var enemy: EnemyData
@export var weight: float = 1.0
## Weight added each round after first_round, so rarer types ramp up.
@export var weight_per_round: float = 0.0
@export var first_round: int = 1
## 0 = no limit.
@export var last_round: int = 0


func get_weight(round_number: int) -> float:
	if round_number < first_round or (last_round > 0 and round_number > last_round):
		return 0.0
	return maxf(weight + weight_per_round * (round_number - first_round), 0.0)

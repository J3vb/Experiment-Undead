## How many points actions are worth. Prices live on the things you buy.
class_name EconomyRules
extends Resource

@export var starting_points: int = 500
@export var points_per_hit: int = 10
@export var points_per_kill: int = 60
@export var headshot_kill_bonus: int = 40
@export var melee_kill_bonus: int = 70
@export var round_clear_bonus: int = 0
## Barrier repair pays per plank, up to a cap per player per round.
@export var points_per_plank: int = 10
@export var max_repair_points_per_round: int = 500

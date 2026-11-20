## Mantle limits and timings (game-design.md Movement: up to 1.2 m, auto on
## push and jump). One file: content/feel/mantle_rules.tres.
class_name MantleRules
extends Resource

## Lowest ledge top above the floor you left that starts a mantle.
@export var min_height: float = 0.5
## Highest ledge top above the floor you left (design cap).
@export var max_height: float = 1.2
## How far past the capsule edge a ledge still counts.
@export var reach: float = 0.45
## Seconds for every mantle, plus time_per_metre for each metre of height.
@export var base_time: float = 0.22
@export var time_per_metre: float = 0.18


func duration(height: float) -> float:
	return base_time + time_per_metre * height

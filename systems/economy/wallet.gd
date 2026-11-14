## Points for one player. Only Economy should change it.
class_name Wallet
extends Node

signal points_changed(total: int, delta: int)

var points: int = 0
## Multiplier hook for power-ups like double points.
var earn_multiplier: float = 1.0

func set_points(value: int) -> void:
	var delta: int = value - points
	points = value
	points_changed.emit(points, delta)

func add(amount: int) -> void:
	if amount == 0:
		return
	var scaled: int = int(round(amount * earn_multiplier)) if amount > 0 else amount
	points += scaled
	points_changed.emit(points, scaled)

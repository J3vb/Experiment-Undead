## Reusable health pool for players, zombies and breakables.
class_name HealthComponent
extends Node

signal damaged(info: DamageInfo)
signal healed(amount: float)
signal health_changed(current: float, maximum: float)
signal died(info: DamageInfo)

@export var max_health: float = 100.0
## Seconds without damage before regeneration starts. 0 disables regen.
@export var regen_delay: float = 0.0
@export var regen_per_second: float = 0.0

var current: float = 0.0
var is_dead: bool = false
var _since_damage: float = 0.0

func _ready() -> void:
	current = max_health

func reset(new_max: float) -> void:
	max_health = new_max
	current = new_max
	is_dead = false
	_since_damage = 0.0
	health_changed.emit(current, max_health)

func take_damage(info: DamageInfo) -> void:
	if is_dead or info.amount <= 0.0:
		return
	current = maxf(current - info.amount, 0.0)
	_since_damage = 0.0
	damaged.emit(info)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit(info)

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0 or current >= max_health:
		return
	var before: float = current
	current = minf(current + amount, max_health)
	healed.emit(current - before)
	health_changed.emit(current, max_health)

func get_ratio() -> float:
	return current / max_health if max_health > 0.0 else 0.0

func _process(delta: float) -> void:
	if is_dead or regen_delay <= 0.0 or current >= max_health:
		return
	_since_damage += delta
	if _since_damage >= regen_delay:
		heal(regen_per_second * delta)

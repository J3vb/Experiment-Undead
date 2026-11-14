## Stats for one enemy type. A new zombie type = a new .tres in
## content/enemies/ (plus a scene only if it needs new behaviour).
## Rounds scale health/speed/damage at spawn; this file is never edited live.
class_name EnemyData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Zombie"
@export var scene: PackedScene

@export_group("Stats")
@export var max_health: float = 100.0
@export var move_speed: float = 1.8
@export var acceleration: float = 8.0
@export var turn_speed: float = 8.0
@export var xp_reward: int = 10

@export_group("Attack")
@export var attack_damage: float = 35.0
@export var attack_range: float = 1.5
@export var attack_windup: float = 0.45
@export var attack_cooldown: float = 1.2

@export_group("Look")
@export var body_scale: float = 1.0
@export var groan_sounds: Array[AudioStream] = []
@export var attack_sound: AudioStream

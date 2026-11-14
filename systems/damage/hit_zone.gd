## A damageable zone (head, body, limb). Bullets hit these, not the movement
## capsule. Passes hits to its owner's HealthComponent with a multiplier.
class_name HitZone
extends Area3D

@export var health: HealthComponent
@export var zone: DamageInfo.Zone = DamageInfo.Zone.BODY
@export var damage_multiplier: float = 1.0

func _ready() -> void:
	collision_layer = Layers.HIT_ZONE
	collision_mask = 0
	monitoring = false

func receive_hit(info: DamageInfo) -> void:
	if health == null or health.is_dead:
		return
	info.amount *= damage_multiplier
	info.hit_zone = zone
	health.take_damage(info)

func set_enabled(enabled: bool) -> void:
	collision_layer = Layers.HIT_ZONE if enabled else 0

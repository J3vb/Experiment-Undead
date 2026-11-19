## One power-up a killed zombie can drop. A new power-up = a new .tres in
## content/power_ups/; its effect is one of Effect, applied in PowerUp.apply_effect().
class_name PowerUpData
extends Resource

## RESUPPLY: full ammo for every player. AMMO_PACK: one magazine per gun for the collector.
enum Effect { RESUPPLY, AMMO_PACK }

@export var id: StringName = &""
@export var display_name: String = "Power-up"
@export var effect: Effect = Effect.RESUPPLY
## Pickup glow, light and label colour; each power-up needs its own so players tell them apart.
@export var color: Color = Color("#8DFF3A")
## Size of the floating pickup; Resupply is big, an ammo pack small.
@export var size: float = 1.0

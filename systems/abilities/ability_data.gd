## One field ability a player can bring into a run (game-design.md "Field abilities").
## A new ability = a new .tres in content/abilities/; its effect is one of Effect, run by AbilityEffects.
class_name AbilityData
extends Resource

## SHOCK_PULSE: pushes back and stuns every zombie within radius for duration.
## MED_BURST, WATCHDOG, ADRENAL_RUSH, DECOY_SIREN: built in later steps of plans/field-abilities.md.
enum Effect { SHOCK_PULSE, MED_BURST, WATCHDOG, ADRENAL_RUSH, DECOY_SIREN }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## The character level that unlocks it.
@export var unlock_level: int = 1
## Seconds before it can be used again, before Gadgeteer and gear shorten it.
@export var cooldown: float = 60.0
@export var effect: Effect = Effect.SHOCK_PULSE
## Metres: pulse, heal or lure reach.
@export var radius: float = 0.0
## Seconds: stun, turret, buff or lure time.
@export var duration: float = 0.0
## Effect strength: Shock Pulse push speed (m/s), Med Burst teammate heal, buff fraction.
@export var amount: float = 0.0

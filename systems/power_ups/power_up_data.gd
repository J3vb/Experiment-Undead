## One power-up a killed zombie can drop. A new power-up = a new .tres in
## content/power_ups/; its effect is one of Effect, run by PowerUpDrops.on_collected().
class_name PowerUpData
extends Resource

## RESUPPLY: full ammo for every player. AMMO_PACK: one magazine per gun for the collector.
## PAYDAY: double hit and kill points for every player while its timer runs.
## OVERKILL: every bullet or melee hit kills while its timer runs.
## STASIS: zombies alive at pickup stand still and cannot attack until its timer ends.
## PURGE: kills every zombie alive now (no kill points, XP or loot). SCRAP_KIT: rebuilds every barricade.
## SUPPLY_CRATE: leaves a crate with one free Specimen Vault roll.
enum Effect { RESUPPLY, AMMO_PACK, PAYDAY, OVERKILL, STASIS, PURGE, SCRAP_KIT, SUPPLY_CRATE }

@export var id: StringName = &""
@export var display_name: String = "Power-up"
@export var effect: Effect = Effect.RESUPPLY
## Pickup glow, light and label colour; each power-up needs its own so players tell them apart.
@export var color: Color = Color("#8DFF3A")
## Size of the floating pickup; Resupply is big, an ammo pack small.
@export var size: float = 1.0
## Seconds a timed power-up lasts for the whole team (HUD ring); 0 = it acts once on pickup.
@export var duration: float = 0.0
## Points every player gets on pickup (Purge, Scrap Kit).
@export var team_points: int = 0
## Chance this power-up is in each new deck (Supply Crate: about 1 deck in 3).
@export var deck_chance: float = 1.0

## One Serum sold by a Med Dispenser. A new Serum = a new .tres in
## content/serums/. Each multiplier scales one player stat while the Serum is
## active; Player.get_stat() multiplies them together.
class_name SerumData
extends Resource

## Stat names code reads through Player.get_stat().
const STATS: Array[StringName] = [
	&"max_health",
	&"reload_time",
	&"fire_interval",
	&"head_damage",
	&"ads_time",
	&"weapon_slots",
	&"sprint_time",
	&"sprint_out_time",
	&"swap_time",
	&"slide_time",
]

## Serums whose effect is code that checks for their id, not a stat.
const EFFECTS: Array[StringName] = [&"second_wind", &"scavenger"]

@export var id: StringName = &""
@export var display_name: String = "Serum"
@export var cost: int = 1000
@export_multiline var description: String = ""
@export var multipliers: Dictionary[StringName, float] = {}
## Up to two letters on the HUD slot, shown when icon is missing.
@export var badge: String = ""
## HUD slot colour.
@export var badge_colour: Color = Color("596b80")
## White line icon on the HUD slot (assets/ui/hud/serum_<id>.svg).
@export var icon: Texture2D

## Rarity trim and glow settings shared by character and gear materials.
class_name RarityLook
extends Resource

@export var rarity: StringName = &"common"
@export var trim_color: Color = Color("d9d9d2")
@export_range(0.0, 2.0) var glow_strength: float = 0.0
@export var pulse_seconds: float = 0.0
@export var flicker: bool = false
## Model tier a piece of this rarity shows: 0 field, 1 plated, 2 Oriel.
@export_range(0, 2) var tier: int = 0

## Rarity counts, tier bonus and source shares; no runtime loot state.
class_name RarityData
extends Resource

@export var id: StringName = &""
@export var colour: Color = Color.WHITE
@export var affix_count_weights: Dictionary[int, float] = {}
@export var tier_bonus: int = 0
@export var zombie_share: float = 0.0
@export var vault_share: float = 0.0

## A slot-filtered loot affix; implicit ammo uses rarity ranges instead of item-level tiers.
class_name AffixData
extends Resource

@export var id: StringName = &""
@export_enum("prefix", "suffix", "implicit") var kind: String = "prefix"
@export var family: StringName = &""
@export var exclusive_families: Array[StringName] = []
@export var slots: Array[StringName] = [&"primary", &"sidearm"]
@export var allowed_tags: Array[StringName] = []
@export var blocked_tags: Array[StringName] = []
@export var min_ilvl: int = 1
@export var min_rarity: StringName = &"common"
@export var stat: StringName = &""
@export_enum("increased", "more", "flat", "proc") var op: String = "increased"
@export var tiers: Array[AffixTier] = []
@export var weight: float = 100.0
@export var step: float = 1.0
@export var text: String = ""
@export var single_value: bool = false
## rarity id -> Vector2(low, high), and rarity id -> weight.
@export var rarity_ranges: Dictionary[StringName, Vector2] = {}
@export var rarity_weights: Dictionary[StringName, float] = {}

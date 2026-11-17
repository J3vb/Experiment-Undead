## One row of the design's speed mix: from first_round on, the share of
## zombies at each WaveRules speed tier (Shamble, Jog, Run, Sprint).
class_name SpeedBand
extends Resource

@export var first_round: int = 1
## One weight per WaveRules.speed_tiers entry; they sum to 1.
@export var weights: PackedFloat64Array = PackedFloat64Array([1.0, 0.0, 0.0, 0.0])

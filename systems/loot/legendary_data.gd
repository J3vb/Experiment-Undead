## A named Legendary: its base, its fixed trait and the trait's range. The trait is a flat stat line that
## the code running it reads by `stat`. Ranges always store low < high; lower_is_better flips the roll.
class_name LegendaryData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var base_id: StringName = &""
@export var stat: StringName = &""
@export var text: String = ""
@export var low: float = 0.0
@export var high: float = 0.0
@export var step: float = 1.0
@export var lower_is_better: bool = false
@export_multiline var flavour: String = ""

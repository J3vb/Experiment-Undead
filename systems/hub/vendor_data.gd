## One Lantern Post stall keeper (F-76): who they are, the stall they stand in, their model, idle clip and the
## lines they say in order when a player talks to them. Read only; the next-line index lives on the Vendor.
class_name VendorData
extends Resource

@export var display_name: String = ""
@export var title: String = ""
## The stall sign they stand behind: MISSIONS, TRADER, GUNSMITH or TECHNICIAN.
@export var stall: StringName = &""
@export var model: PackedScene
@export var idle_clip: StringName = &"counter_idle"
@export var lines: Array[String] = []

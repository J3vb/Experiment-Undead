## Root of a map's atmosphere scene (cosmetic lights, particles, fog). It sits
## directly under the Level and swaps two groups with the power: "after_power"
## nodes (steam, hums) show once the power is on, "before_power" nodes hide.
## Reading Level.power_on at ready covers late joiners in co-op.
class_name Atmosphere
extends Node3D

const AFTER_POWER: StringName = &"after_power"
const BEFORE_POWER: StringName = &"before_power"

var powered: bool = false
var _after: Array[Node3D] = []
var _before: Array[Node3D] = []


func _ready() -> void:
	for node: Node in find_children("*", "Node3D", true, false):
		if node.is_in_group(AFTER_POWER):
			_after.append(node as Node3D)
		elif node.is_in_group(BEFORE_POWER):
			_before.append(node as Node3D)
	var level: Level = get_parent() as Level
	set_powered(level != null and level.power_on)
	if level and not level.power_on:
		level.power_turned_on.connect(set_powered.bind(true), CONNECT_ONE_SHOT)


func set_powered(on: bool) -> void:
	powered = on
	for node: Node3D in _after:
		node.visible = on
	for node: Node3D in _before:
		node.visible = not on

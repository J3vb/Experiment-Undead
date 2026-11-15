## Kit ceiling light: housing, glowing tube and a spot; LightmapGI bakes its bounce.
## The builder turns the shadow on for a few lights per room (light budget).
## Inside a Level whose power is off it runs as a dim red-orange emergency
## light, and switches to normal shortly after the power comes on.
class_name CeilingLight
extends Node3D

const EMERGENCY_COLOR: Color = Color(1.0, 0.32, 0.12)
const EMERGENCY_DIM: float = 0.3
const EMERGENCY_TUBE: Material = preload("res://levels/materials/emergency_tube.tres")
## Lights come on in a ragged wave over this many seconds after power-on.
const POWER_ON_SPREAD: float = 0.6

@export var casts_shadow: bool = false
@export var flickers: bool = false

var emergency: bool = false
var _flicker: FlickerLight

@onready var _spot: SpotLight3D = $Fixture
@onready var _tube: MeshInstance3D = $Tube
@onready var _normal_color: Color = _spot.light_color
@onready var _spot_energy: float = _spot.light_energy


func _ready() -> void:
	_spot.shadow_enabled = casts_shadow
	var level: Level = _find_level()
	if level and not level.power_on:
		_set_emergency(true)
		level.power_turned_on.connect(_on_power_on, CONNECT_ONE_SHOT)
	if flickers:
		_flicker = FlickerLight.new()
		_flicker.light = _spot
		add_child(_flicker)


func _on_power_on() -> void:
	await get_tree().create_timer(randf() * POWER_ON_SPREAD).timeout  # cosmetic
	_set_emergency(false)


func _set_emergency(on: bool) -> void:
	emergency = on
	var dim: float = EMERGENCY_DIM if on else 1.0
	var color: Color = EMERGENCY_COLOR if on else _normal_color
	_spot.light_color = color
	_spot.light_energy = _spot_energy * dim
	_tube.material_override = EMERGENCY_TUBE if on else null
	if _flicker:
		_flicker.base_energy = _spot.light_energy


func _find_level() -> Level:
	var node: Node = get_parent()
	while node and not node is Level:
		node = node.get_parent()
	return node as Level

## Kit ceiling light: housing, glowing tube, a spot and a weak spill light.
## The builder turns the shadow on for a few lights per room (light budget).
class_name CeilingLight
extends Node3D

@export var casts_shadow: bool = false
@export var flickers: bool = false


func _ready() -> void:
	var spot: SpotLight3D = $Fixture
	spot.shadow_enabled = casts_shadow
	if flickers:
		var flicker: FlickerLight = FlickerLight.new()
		flicker.light = spot
		add_child(flicker)

## Darkens a map's baked light during a Blackout and brings it back after. Visual only, on every peer:
## the lightmap is taken off (its bounce came from the ceiling lights) and the ambient fill drops, so only
## Fenlight leaks, fire, Glowers and flashlights light the rooms.
class_name BlackoutDimmer
extends Node

## Share of the look's ambient light left on in a Blackout.
const AMBIENT_LEFT: float = 0.25

@export var lightmap: LightmapGI
@export var world: WorldEnvironment

var dark: bool = false
var _light_data: LightmapGIData
var _ambient: float = 0.0


func _ready() -> void:
	Events.blackout_started.connect(set_dark.bind(true).unbind(1))
	Events.blackout_ended.connect(set_dark.bind(false).unbind(1))


func set_dark(on: bool) -> void:
	if on == dark:
		return
	dark = on
	var look: Environment = world.environment
	if on:
		_light_data = lightmap.light_data
		lightmap.light_data = null
		_ambient = look.ambient_light_energy
		look.ambient_light_energy = _ambient * AMBIENT_LEFT
	else:
		lightmap.light_data = _light_data
		look.ambient_light_energy = _ambient

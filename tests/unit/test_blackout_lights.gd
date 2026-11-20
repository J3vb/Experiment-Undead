## A Blackout turns every Halcyon Labs ceiling light fully dark and takes the baked bounce off; when it ends the
## lights go back to the power state (emergency or mains), and power coming on mid-Blackout keeps the room dark.
extends GutTest

const MAP: String = "res://levels/halcyon_labs/map.tscn"

var _level: Level


func before_each() -> void:
	_level = (load(MAP) as PackedScene).instantiate() as Level
	add_child_autofree(_level)


func _lights() -> Array[CeilingLight]:
	var out: Array[CeilingLight] = []
	for node: Node in _level.find_children("*", "Node3D"):
		if node is CeilingLight:
			out.append(node as CeilingLight)
	return out


func _assert_dark(light: CeilingLight) -> void:
	assert_false((light.get_node("Fixture") as SpotLight3D).visible, "%s spot off" % light.name)
	assert_eq((light.get_node("Tube") as MeshInstance3D).material_override, CeilingLight.DARK_TUBE)


func test_blackout_darkens_emergency_lights_and_brings_them_back() -> void:
	Events.blackout_started.emit(6)
	for light: CeilingLight in _lights():
		_assert_dark(light)
	Events.blackout_ended.emit(6)
	for light: CeilingLight in _lights():
		assert_true((light.get_node("Fixture") as SpotLight3D).visible, "%s spot back" % light.name)
		var tube: MeshInstance3D = light.get_node("Tube") as MeshInstance3D
		assert_eq(tube.material_override, CeilingLight.EMERGENCY_TUBE, "power still off: emergency again")


func test_blackout_with_power_on_comes_back_to_mains() -> void:
	_level.turn_power_on()
	await wait_seconds(CeilingLight.POWER_ON_SPREAD + 0.2)
	Events.blackout_started.emit(6)
	for light: CeilingLight in _lights():
		_assert_dark(light)
	Events.blackout_ended.emit(6)
	for light: CeilingLight in _lights():
		assert_true((light.get_node("Fixture") as SpotLight3D).visible)
		assert_null((light.get_node("Tube") as MeshInstance3D).material_override, "%s on mains" % light.name)


func test_power_on_mid_blackout_stays_dark_until_it_ends() -> void:
	Events.blackout_started.emit(6)
	_level.turn_power_on()
	await wait_seconds(CeilingLight.POWER_ON_SPREAD + 0.2)
	for light: CeilingLight in _lights():
		_assert_dark(light)
		assert_false(light.emergency, "power state underneath is mains")
	Events.blackout_ended.emit(6)
	for light: CeilingLight in _lights():
		assert_null((light.get_node("Tube") as MeshInstance3D).material_override)


func test_dimmer_takes_the_lightmap_and_ambient_down_and_restores_them() -> void:
	var dimmer: BlackoutDimmer = _level.get_node("BlackoutDimmer") as BlackoutDimmer
	var lightmap: LightmapGI = _level.get_node("LightmapGI") as LightmapGI
	var look: Environment = (_level.get_node("WorldEnvironment") as WorldEnvironment).environment
	var data: LightmapGIData = lightmap.light_data
	var ambient: float = look.ambient_light_energy
	assert_not_null(data, "the map has baked light")
	Events.blackout_started.emit(6)
	assert_true(dimmer.dark)
	assert_null(lightmap.light_data, "baked bounce off")
	assert_almost_eq(look.ambient_light_energy, ambient * BlackoutDimmer.AMBIENT_LEFT, 0.0001)
	Events.blackout_started.emit(6)
	Events.blackout_ended.emit(6)
	assert_eq(lightmap.light_data, data, "baked bounce back")
	assert_almost_eq(look.ambient_light_energy, ambient, 0.0001, "a repeated start does not lose the ambient")

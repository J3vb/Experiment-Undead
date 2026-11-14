## Before the power is on, Halcyon Labs runs on dim red-orange emergency
## light; the power switch brings back the normal cold tubes. A light outside
## a Level (look reference, kit previews) always shows normal light.
extends GutTest

const MAP: String = "res://levels/halcyon_labs/map.tscn"
const LIGHT: String = "res://levels/kit/ceiling_light.tscn"


func _lights(root: Node) -> Array[CeilingLight]:
	var out: Array[CeilingLight] = []
	for node: Node in root.find_children("*", "Node3D"):
		if node is CeilingLight:
			out.append(node as CeilingLight)
	return out


func test_map_starts_on_emergency_light_and_power_restores_it() -> void:
	var level: Level = (load(MAP) as PackedScene).instantiate() as Level
	add_child_autofree(level)
	var lights: Array[CeilingLight] = _lights(level)
	assert_gt(lights.size(), 20, "the map has its ceiling lights")
	var normal_energy: float = 0.0
	for light: CeilingLight in lights:
		var spot: SpotLight3D = light.get_node("Fixture") as SpotLight3D
		assert_true(light.emergency, "%s on emergency power" % light.name)
		assert_eq(spot.light_color, CeilingLight.EMERGENCY_COLOR)
		assert_eq((light.get_node("Tube") as MeshInstance3D).material_override, CeilingLight.EMERGENCY_TUBE)
		normal_energy = spot.light_energy / CeilingLight.EMERGENCY_DIM
	level.turn_power_on()
	await wait_seconds(CeilingLight.POWER_ON_SPREAD + 0.2)
	for light: CeilingLight in lights:
		var spot: SpotLight3D = light.get_node("Fixture") as SpotLight3D
		assert_false(light.emergency, "%s back on mains" % light.name)
		assert_ne(spot.light_color, CeilingLight.EMERGENCY_COLOR)
		assert_null((light.get_node("Tube") as MeshInstance3D).material_override)
		if not light.flickers:
			assert_almost_eq(spot.light_energy, normal_energy, 0.001, "full brightness")


func test_flickering_lights_flicker_around_the_new_level() -> void:
	var level: Level = (load(MAP) as PackedScene).instantiate() as Level
	add_child_autofree(level)
	var flicker: FlickerLight = null
	for node: Node in level.find_children("*", "Node"):
		if node is FlickerLight:
			flicker = node as FlickerLight
			break
	if flicker == null:
		pass_test("no flickering lights on this map")
		return
	var dim: float = flicker.base_energy
	level.turn_power_on()
	await wait_seconds(CeilingLight.POWER_ON_SPREAD + 0.2)
	assert_almost_eq(flicker.base_energy, dim / CeilingLight.EMERGENCY_DIM, 0.001)


func test_light_outside_a_level_stays_normal() -> void:
	var light: CeilingLight = (load(LIGHT) as PackedScene).instantiate() as CeilingLight
	add_child_autofree(light)
	assert_false(light.emergency, "no Level means no power system")
	assert_null((light.get_node("Tube") as MeshInstance3D).material_override)

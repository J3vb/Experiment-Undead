## Atmosphere: after_power nodes stay hidden until the Level's power comes on,
## before_power nodes hide then, and a scene added after power (a late joiner)
## starts in the powered state. Monitor screens anywhere under the Level get the
## "powered" instance uniform.
extends GutTest

const HISS: String = "res://assets/audio/ambience/steam_hiss.ogg"


func _level(power_on: bool) -> Level:
	var level: Level = Level.new()
	level.power_on = power_on
	return level


func _atmosphere() -> Atmosphere:
	var atmosphere: Atmosphere = Atmosphere.new()
	var after: Node3D = Node3D.new()
	after.name = "Steam"
	after.add_to_group(Atmosphere.AFTER_POWER)
	atmosphere.add_child(after)
	var hiss: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	hiss.name = "Hiss"
	hiss.stream = load(HISS) as AudioStream
	after.add_child(hiss)
	var before: Node3D = Node3D.new()
	before.name = "Static"
	before.add_to_group(Atmosphere.BEFORE_POWER)
	atmosphere.add_child(before)
	return atmosphere


func test_power_swaps_the_groups() -> void:
	var level: Level = _level(false)
	var atmosphere: Atmosphere = _atmosphere()
	level.add_child(atmosphere)
	add_child_autofree(level)
	assert_false((atmosphere.get_node("Steam") as Node3D).visible, "steam waits for power")
	assert_false((atmosphere.get_node("Steam/Hiss") as AudioStreamPlayer3D).playing, "silent before power")
	assert_true((atmosphere.get_node("Static") as Node3D).visible)
	level.turn_power_on()
	assert_true(atmosphere.powered)
	assert_true((atmosphere.get_node("Steam") as Node3D).visible, "steam starts with power")
	assert_true((atmosphere.get_node("Steam/Hiss") as AudioStreamPlayer3D).playing, "and its hiss with it")
	assert_false((atmosphere.get_node("Static") as Node3D).visible)


func test_late_joiner_starts_powered() -> void:
	var level: Level = _level(true)
	var atmosphere: Atmosphere = _atmosphere()
	level.add_child(atmosphere)
	add_child_autofree(level)
	assert_true(atmosphere.powered)
	assert_true((atmosphere.get_node("Steam") as Node3D).visible)
	assert_false((atmosphere.get_node("Static") as Node3D).visible)


func test_outside_a_level_stays_unpowered() -> void:
	var atmosphere: Atmosphere = _atmosphere()
	add_child_autofree(atmosphere)
	assert_false(atmosphere.powered)


func _screen(parent: Node) -> MeshInstance3D:
	var screen: MeshInstance3D = MeshInstance3D.new()
	screen.mesh = QuadMesh.new()
	screen.set_surface_override_material(0, Atmosphere.MONITOR_SCREEN)
	parent.add_child(screen)
	return screen


func test_screens_under_the_level_follow_the_power() -> void:
	var level: Level = _level(false)
	var prop_screen: MeshInstance3D = _screen(level)
	var atmosphere: Atmosphere = _atmosphere()
	level.add_child(atmosphere)
	add_child_autofree(level)
	assert_eq(atmosphere.screens().size(), 1, "finds the prop's screen outside its own scene")
	assert_eq(prop_screen.get_instance_shader_parameter(&"powered"), 0.0, "dark before power")
	level.turn_power_on()
	assert_eq(prop_screen.get_instance_shader_parameter(&"powered"), 1.0, "lit after power")

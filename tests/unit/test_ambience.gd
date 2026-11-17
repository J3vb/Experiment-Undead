## Halcyon Labs ambience: beds on the Ambient bus, area crossfade, ducking under music.
extends GutTest

const AMBIENCE: PackedScene = preload("res://levels/halcyon_labs/ambience.tscn")
const MAP: PackedScene = preload("res://levels/halcyon_labs/map.tscn")

var ambience: Ambience


func before_each() -> void:
	ambience = AMBIENCE.instantiate() as Ambience
	add_child_autofree(ambience)


func test_beds_play_from_start_on_ambient_bus() -> void:
	assert_eq(ambience.beds().size(), 4, "default + corridor + mess hall + labs")
	for bed: AudioStreamPlayer in ambience.beds():
		assert_eq(bed.bus, &"Ambient")
		assert_true(bed.playing, "%s plays from map start" % bed.get_parent().name)
		var stream: AudioStreamOggVorbis = bed.stream as AudioStreamOggVorbis
		assert_true(stream.loop, "%s loops" % stream.resource_path)
	assert_eq(ambience.one_shot.bus, &"Ambient")


func test_default_bed_is_audible_until_an_area_is_entered() -> void:
	assert_eq(ambience.active_bed(), ambience.default_bed)
	assert_eq(ambience.default_bed.volume_db, ambience.bed_volume_db)
	var labs: Area3D = ambience.get_node("Labs") as Area3D
	assert_eq(ambience.target_volume_db(labs.get_node("Bed") as AudioStreamPlayer), -80.0)


func test_entering_and_leaving_areas_switches_bed() -> void:
	var corridor: Area3D = ambience.get_node("MainCorridor") as Area3D
	var hall: Area3D = ambience.get_node("MessHall") as Area3D
	ambience.enter(corridor)
	assert_eq(ambience.active_bed(), corridor.get_node("Bed"))
	assert_eq(ambience.target_volume_db(ambience.default_bed), -80.0)
	ambience.enter(hall)
	ambience.leave(corridor)
	assert_eq(ambience.active_bed(), hall.get_node("Bed"), "leaving an old area keeps the new one")
	ambience.leave(hall)
	assert_eq(ambience.active_bed(), ambience.default_bed)


func test_areas_watch_only_players() -> void:
	for zone_name: String in ["MainCorridor", "MessHall", "Labs"]:
		var zone: Area3D = ambience.get_node(zone_name) as Area3D
		assert_eq(zone.collision_mask, Layers.PLAYER)
		assert_eq(zone.collision_layer, 0)


func test_ambient_bus_ducks_under_music() -> void:
	var bus: int = AudioServer.get_bus_index(&"Ambient")
	assert_gt(AudioServer.get_bus_effect_count(bus), 0)
	var compressor: AudioEffectCompressor = AudioServer.get_bus_effect(bus, 0) as AudioEffectCompressor
	assert_not_null(compressor)
	assert_eq(compressor.sidechain, &"Music")
	assert_true(AudioServer.is_bus_effect_enabled(bus, 0))


func test_halcyon_map_has_ambience() -> void:
	var state: SceneState = MAP.get_state()
	var found: bool = false
	for index: int in state.get_node_count():
		if state.get_node_name(index) == &"Ambience":
			found = true
	assert_true(found)

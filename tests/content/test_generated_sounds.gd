## Every generated machine sound imports as a nonempty, finite one-shot WAV.
extends GutTest


func test_machine_sounds_load() -> void:
	for name: String in [
		"buy", "denied", "door_open", "power_on", "plank_tear", "plank_repair", "power_up", "round_end"
	]:
		var sound: AudioStreamWAV = load("res://assets/audio/%s.wav" % name) as AudioStreamWAV
		assert_not_null(sound, name)
		if sound:
			assert_gt(sound.get_length(), 0.0, name)
			assert_eq(sound.loop_mode, AudioStreamWAV.LOOP_DISABLED, name)


func test_zombie_sounds_load() -> void:
	var names: Array[String] = []
	for index: int in range(1, 5):
		names.append_array(["zombie_step_%d" % index, "bloater_step_%d" % index, "impact_flesh_%d" % index])
	for index: int in range(1, 4):
		names.append_array(["zombie_death_%d" % index, "bloater_gurgle_%d" % index])
	names.append_array(["bloater_death_1", "bloater_death_2", "hit_head_1", "hit_head_2"])
	for name: String in names:
		var sound: AudioStreamWAV = load("res://assets/audio/%s.wav" % name) as AudioStreamWAV
		assert_not_null(sound, name)
		if sound:
			assert_gt(sound.get_length(), 0.0, name)
			assert_eq(sound.loop_mode, AudioStreamWAV.LOOP_DISABLED, name)

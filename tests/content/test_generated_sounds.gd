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

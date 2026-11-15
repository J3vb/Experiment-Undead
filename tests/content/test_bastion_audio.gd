## Bastion's report is a one-shot; its quieter feed-drive layer loops independently.
extends GutTest


func test_report_is_a_short_one_shot() -> void:
	var report: AudioStreamWAV = load("res://assets/audio/bastion_fire.wav") as AudioStreamWAV
	assert_not_null(report)
	if report:
		assert_almost_eq(report.get_length(), 0.24, 0.001)
		assert_eq(report.loop_mode, AudioStreamWAV.LOOP_DISABLED)


func test_spin_up_layer_loops_the_complete_period() -> void:
	var layer: AudioStreamWAV = load("res://assets/audio/bastion_spin_up.wav") as AudioStreamWAV
	assert_not_null(layer)
	if layer:
		assert_almost_eq(layer.get_length(), 0.5, 0.001)
		assert_eq(layer.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_eq(layer.loop_begin, 0)
		assert_eq(layer.loop_end, 22050)
		assert_eq(layer.mix_rate, 44100)

## Mashing interact while broke plays the denied sound once, not once per press.
extends GutTest

const WALL_BUY: PackedScene = preload("res://systems/interactables/wall_buy.tscn")

var machine: Interactable
var denied: AudioStreamPlayer3D
var starts: int = 0


func before_each() -> void:
	starts = 0
	machine = WALL_BUY.instantiate() as Interactable
	add_child_autofree(machine)
	denied = machine.get_node(^"DeniedSound") as AudioStreamPlayer3D
	denied.stream = _tone(0.5)


func _tone(seconds: float) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.mix_rate = 8000
	wav.data = PackedByteArray()
	wav.data.resize(int(8000 * seconds))
	return wav


func test_repeated_denials_do_not_restart_the_sound() -> void:
	machine.play_result(false)
	assert_true(denied.playing, "first denial plays")
	var first: AudioStreamPlayback = denied.get_stream_playback()
	machine.play_result(false)
	machine.play_result(false)
	assert_true(denied.playing)
	assert_eq(denied.get_stream_playback(), first, "every play() starts a new playback; mashing must not")


func test_denied_plays_again_once_it_has_finished() -> void:
	machine.play_result(false)
	denied.stop()
	machine.play_result(false)
	assert_true(denied.playing, "a press after the sound ended is heard")

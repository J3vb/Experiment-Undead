## A zombie's mouth: groans on a random timer and plays one-off sounds
## (attack, plank tear). Presentation only.
class_name ZombieVoice
extends AudioStreamPlayer3D

var groans: Array[AudioStream] = []
var _timer: float = 0.0


func _ready() -> void:
	_timer = randf_range(1.0, 5.0)


func _process(delta: float) -> void:
	if groans.is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(3.0, 8.0)
		say(groans[randi() % groans.size()])


func say(sound: AudioStream) -> void:
	if sound == null:
		return
	stream = sound
	pitch_scale = randf_range(0.85, 1.15)
	play()


func silence() -> void:
	set_process(false)
	stop()

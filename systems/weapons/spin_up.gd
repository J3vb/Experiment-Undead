## Held-trigger fire-rate ramp with an optional rising-pitch mechanical layer.
class_name SpinUp
extends RefCounted

const START_RATE: float = 0.4
const START_PITCH: float = 0.6
const END_PITCH: float = 1.2

var _duration: float = 0.0
var _elapsed: float = 0.0
var _audio: AudioStreamPlayer


func configure(duration: float, audio: AudioStreamPlayer = null) -> void:
	reset()
	_duration = duration
	_audio = audio
	reset()


func tick(delta: float, held: bool) -> void:
	if not held or _duration <= 0.0:
		reset()
		return
	_elapsed += maxf(delta, 0.0)
	if is_instance_valid(_audio):
		_audio.pitch_scale = lerpf(START_PITCH, END_PITCH, minf(_elapsed / _duration, 1.0))
		if not _audio.playing and _audio.stream:
			_audio.play()


## Negative offset samples a catch-up shot's time within the current physics tick.
func scale_interval(base_interval: float, offset: float = 0.0) -> float:
	if _duration <= 0.0:
		return base_interval
	var progress: float = clampf((_elapsed + offset) / _duration, 0.0, 1.0)
	return base_interval / lerpf(START_RATE, 1.0, progress)


func reset() -> void:
	_elapsed = 0.0
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.pitch_scale = START_PITCH

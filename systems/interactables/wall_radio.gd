## A wall radio for the Halcyon Labs secret. After power it hums its tone now
## and then; pressing it plays the tone and tells its parent RadioPuzzle, which
## decides (on the server) whether it lights up or everything resets with static.
## Pitch, lit state and play counters sync to clients through net_state().
class_name WallRadio
extends Interactable

signal pressed(radio: WallRadio)

## Tone pitch per rank: 0 = lowest, 2 = highest.
const PITCHES: Array[float] = [0.75, 1.0, 1.3]
const IDLE_GAP: float = 8.0
const FIRST_IDLE_STAGGER: float = 2.7

## -1 until the puzzle rolls the pitches at power-on.
var pitch: int = -1
var lit: bool = false
var _beeps: int = 0
var _fails: int = 0


func _ready() -> void:
	super()
	add_to_group(&"wall_radio")
	($Idle as Timer).timeout.connect(_on_idle)


func get_prompt(_player: Player) -> String:
	return "" if pitch < 0 or lit else "Tune radio [F]"


func interact(_player: Player, _facts: Dictionary = {}) -> void:
	if pitch >= 0 and not lit:
		pressed.emit(self)


## Server: the puzzle hands out this radio's tone.
func set_pitch(rank: int) -> void:
	pitch = rank
	_refresh()
	state_changed.emit()


## Server: play the tone for everyone, then light up (right press) or not.
func answer(right: bool) -> void:
	_beeps += 1
	_play(^"Tone")
	lit = right
	_refresh()
	state_changed.emit()


## Server: a wrong press somewhere; every radio goes dark, this one with static.
func reset(with_static: bool) -> void:
	lit = false
	if with_static:
		_fails += 1
		_play(^"Static")
	_refresh()
	state_changed.emit()


func net_state() -> Dictionary:
	return {"pitch": pitch, "lit": lit, "beeps": _beeps, "fails": _fails}


func apply_net_state(state: Dictionary) -> void:
	pitch = state.get("pitch", -1)
	lit = state.get("lit", false)
	if int(state.get("beeps", 0)) > _beeps:
		_play(^"Tone")
	if int(state.get("fails", 0)) > _fails:
		_play(^"Static")
	_beeps = state.get("beeps", 0)
	_fails = state.get("fails", 0)
	_refresh()


func _refresh() -> void:
	($Lamp as Node3D).visible = lit
	var idle: Timer = $Idle as Timer
	if pitch < 0 or lit:
		idle.stop()
	elif idle.is_stopped():
		idle.start(1.0 + get_index() * FIRST_IDLE_STAGGER)


func _on_idle() -> void:
	_play(^"Tone")
	($Idle as Timer).start(IDLE_GAP)


func _play(sound: NodePath) -> void:
	var player: AudioStreamPlayer3D = get_node(sound) as AudioStreamPlayer3D
	if sound == ^"Tone":
		player.pitch_scale = PITCHES[pitch]
	player.play()

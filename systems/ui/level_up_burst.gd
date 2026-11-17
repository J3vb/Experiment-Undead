## Level-up moment behind the XP bar: a brass ring grows and fades, and the level_up sting plays (game-feel.md).
## Only for the local player; no screen effect.
class_name LevelUpBurst
extends Control

const BRASS: Color = Color("e3cf9a")
const DURATION: float = 0.6
const MAX_RADIUS: float = 90.0
const WIDTH: float = 3.0

var _progress: float = 1.0
var _tween: Tween

@onready var sting: AudioStreamPlayer = $Sting


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.player_leveled_up.connect(_on_player_leveled_up)


func is_playing() -> bool:
	return _progress < 1.0


func play() -> void:
	if _tween:
		_tween.kill()
	_progress = 0.0
	sting.play()
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_player_leveled_up(player: Player, _level: int) -> void:
	if player and player.is_inside_tree() and player.is_multiplayer_authority():
		play()


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	if _progress >= 1.0:
		return
	var colour: Color = BRASS
	colour.a = 1.0 - _progress
	draw_arc(size * 0.5, maxf(MAX_RADIUS * _progress, 1.0), 0.0, TAU, 48, colour, WIDTH, true)

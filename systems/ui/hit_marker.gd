## X-shaped hit marker. White = hit, red = kill, bigger on headshot kills.
class_name HitMarker
extends Control

@export var hit_color: Color = Color(1, 1, 1)
@export var kill_color: Color = Color(1, 0.15, 0.1)
@export var duration: float = 0.18

var _time: float = 0.0
var _color: Color = Color.WHITE
var _scale: float = 1.0

func show_hit(is_kill: bool, is_headshot: bool) -> void:
	_time = duration * (1.6 if is_kill else 1.0)
	_color = kill_color if is_kill else hit_color
	_scale = 1.4 if is_kill and is_headshot else (1.15 if is_kill else 1.0)
	queue_redraw()

func _process(delta: float) -> void:
	if _time > 0.0:
		_time -= delta
		queue_redraw()

func _draw() -> void:
	if _time <= 0.0:
		return
	var c: Vector2 = size * 0.5
	var a: float = clampf(_time / duration, 0.0, 1.0)
	var col: Color = Color(_color, a)
	var inner: float = 6.0 * _scale
	var outer: float = 14.0 * _scale
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n: Vector2 = d.normalized()
		draw_line(c + n * inner, c + n * outer, col, 2.5)

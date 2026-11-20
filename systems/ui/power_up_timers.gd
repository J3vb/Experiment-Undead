## Bottom-centre HUD row: one coloured disc per running timed power-up, with its name under it
## and a ring that shrinks as the time runs out. Blinks for the last BLINK_TIME seconds.
## Counts down locally from Events.power_up_timer_started; the server owns the real timer.
class_name PowerUpTimers
extends Control

const RADIUS: float = 22.0
const RING_WIDTH: float = 4.0
const SPACING: float = 84.0
const BLINK_TIME: float = 5.0
const FONT_SIZE: int = 14
const DISC_ALPHA: float = 0.35

var _left: Dictionary[PowerUpData, float] = {}
var _full: Dictionary[PowerUpData, float] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.power_up_timer_started.connect(_on_timer_started)


## Seconds this HUD shows left for data, 0 when its ring is gone.
func time_left(data: PowerUpData) -> float:
	return _left.get(data, 0.0)


func _process(delta: float) -> void:
	if _left.is_empty():
		return
	var ended: PowerUpData = null
	for data: PowerUpData in _left:
		_left[data] -= delta
		if _left[data] <= 0.0:
			ended = data
	if ended:
		_left.erase(ended)
		_full.erase(ended)
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var x: float = size.x * 0.5 - SPACING * (_left.size() - 1) * 0.5
	for data: PowerUpData in _left:
		var left: float = _left[data]
		if left > BLINK_TIME or fmod(left, 0.4) < 0.25:
			_draw_icon(data, Vector2(x, RADIUS + RING_WIDTH), left / _full[data], font)
		x += SPACING


func _draw_icon(data: PowerUpData, centre: Vector2, share: float, font: Font) -> void:
	var tint: Color = data.color
	draw_circle(centre, RADIUS, Color(tint, DISC_ALPHA))
	draw_arc(centre, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * share, 48, tint, RING_WIDTH, true)
	var text: String = data.display_name.to_upper()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var base: Vector2 = centre + Vector2(-width * 0.5, RADIUS + RING_WIDTH + FONT_SIZE + 2.0)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, tint.lerp(Color.WHITE, 0.3))


func _on_timer_started(data: PowerUpData, seconds: float) -> void:
	_left[data] = seconds
	_full[data] = maxf(data.duration, seconds)
	queue_redraw()

## Top-right round counter from the concept art (docs/design/concepts/screens/hud_concept_2.jpg):
## "ROUND 3" in white with a red stroke under it, and the map name below. The stroke fades in
## when a round starts; the text blinks during the break. Hidden until the first round or break
## (so it never shows in the town).
class_name RoundCounter
extends VBoxContainer

const DANGER: Color = Color("c3201b")
const STROKE_HEIGHT: float = 4.0
const BLINK_ALPHA: float = 0.3

var underline: float = 0.0
var _tween: Tween

@onready var label: Label = $RoundLabel


func _ready() -> void:
	label.text = ""
	visible = false
	label.resized.connect(queue_redraw)
	Events.round_started.connect(_on_round_started)
	Events.intermission_started.connect(_on_intermission)


## Shows round_number as the current round with the full stroke (also used by look renders).
func show_round(round_number: int) -> void:
	label.text = "ROUND %d" % round_number
	label.modulate = Color.WHITE
	visible = true
	underline = 1.0
	queue_redraw()


func _draw() -> void:
	if underline <= 0.0 or label.text.is_empty():
		return
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 24.0
	var right: float = label.position.x + label.size.x
	var top: float = label.position.y + label.size.y - 6.0
	var solid: Color = Color(DANGER, underline)
	var clear: Color = Color(DANGER, 0.0)
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2(right - width, top + 1.0),
			Vector2(right, top),
			Vector2(right, top + STROKE_HEIGHT),
			Vector2(right - width, top + STROKE_HEIGHT - 1.0)
		]
	)
	draw_polygon(points, PackedColorArray([clear, solid, solid, clear]))


func _set_underline(value: float) -> void:
	underline = value
	queue_redraw()


func _on_round_started(round_number: int, _count: int) -> void:
	if _tween:
		_tween.kill()
	show_round(round_number)
	underline = 0.0
	_tween = create_tween()
	_tween.tween_method(_set_underline, 0.0, 1.0, 1.0)


func _on_intermission(next_round: int, _duration: float) -> void:
	if next_round <= 1:
		return
	if _tween:
		_tween.kill()
	show_round(next_round - 1)
	_tween = create_tween().set_loops()
	_tween.tween_property(label, "modulate:a", BLINK_ALPHA, 0.8)
	_tween.tween_property(label, "modulate:a", 1.0, 0.8)

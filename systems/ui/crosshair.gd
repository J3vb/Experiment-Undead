## Four-line crosshair whose gap follows the weapon's real spread.
class_name Crosshair
extends Control

@export var color: Color = Color(1, 1, 1, 0.85)
@export var line_length: float = 9.0
@export var thickness: float = 2.0
@export var min_gap: float = 4.0

## 0 hides the four lines (aiming, sprinting, down); the centre dot setting keeps a dot.
var lines_alpha: float = 1.0
var centre_dot: bool = false
var spread_degrees: float = 2.0
var fov_degrees: float = 78.0
var _gap: float = 8.0


func _ready() -> void:
	centre_dot = Settings.get_value(&"comfort", &"centre_dot")
	Settings.changed.connect(_on_setting_changed)


func _on_setting_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"comfort" and key == &"centre_dot":
		centre_dot = value


func _process(delta: float) -> void:
	var viewport_h: float = get_viewport_rect().size.y
	var half_fov: float = deg_to_rad(fov_degrees) * 0.5
	var target: float = tan(deg_to_rad(spread_degrees)) / tan(half_fov) * viewport_h * 0.5
	_gap = lerpf(_gap, maxf(target, min_gap), clampf(delta * 20.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var shadow: Color = Color(0, 0, 0, color.a * 0.6)
	if centre_dot:
		draw_circle(c + Vector2.ONE, thickness + 0.5, shadow)
		draw_circle(c, thickness, color)
	if lines_alpha <= 0.0:
		return
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var a: Vector2 = c + dir * _gap
		var b: Vector2 = c + dir * (_gap + line_length)
		draw_line(a + Vector2.ONE, b + Vector2.ONE, shadow, thickness)
		draw_line(a, b, color, thickness)

## Bottom-left HUD panel from the concept art (docs/design/concepts/screens/hud_concept.jpg):
## a health cross with five health segments and a runner with the sprint bar, in an angled
## dark panel. Shows the local player only and redraws only when a shown value changes.
class_name VitalsPanel
extends Control

const SEGMENTS: int = 5
const LOW_HEALTH: float = 0.3
const PANEL: Color = Color(0.071, 0.102, 0.125, 0.88)
const LINE: Color = Color("2c3b44")
const TEXT: Color = Color("e6ecec")
const DIM: Color = Color(0.561, 0.639, 0.659, 0.25)
const WARN: Color = Color("ff9f1c")
const DANGER: Color = Color("c3201b")
const CUT: float = 14.0
const PAD: float = 16.0
const ICON: float = 26.0
const BAR_HEIGHT: float = 12.0
const GAP: float = 5.0
const STAMINA_STEP: float = 0.005

var player: Player
var health_share: float = 1.0
var stamina_share: float = 1.0
var cooling: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(360.0, 72.0)
	Events.player_spawned.connect(_on_player_spawned)
	Events.player_health_changed.connect(_on_health_changed)


## Health shown as segments, 0 to SEGMENTS; the last one may be part filled.
func filled_segments() -> float:
	return health_share * SEGMENTS


func health_colour() -> Color:
	return DANGER if health_share < LOW_HEALTH else TEXT


func stamina_colour() -> Color:
	return WARN if cooling else TEXT


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var full: float = player.sprint_time * player.get_stat(&"sprint_time")
	var share: float = clampf(player.sprint_left / maxf(full, 0.01), 0.0, 1.0)
	var cool: bool = not player.can_sprint()
	if absf(share - stamina_share) >= STAMINA_STEP or cool != cooling or (share >= 1.0) != (stamina_share >= 1.0):
		stamina_share = share
		cooling = cool
		queue_redraw()


func _draw() -> void:
	_draw_panel()
	var top_row: float = size.y * 0.34
	var bottom_row: float = size.y * 0.7
	var icon_centre: float = PAD + ICON * 0.5
	var left: float = PAD + ICON + 12.0
	var width: float = size.x - left - PAD - CUT * 0.5
	_draw_cross(Vector2(icon_centre, top_row))
	_draw_segments(left, top_row - BAR_HEIGHT * 0.5, width)
	_draw_runner(Vector2(icon_centre, bottom_row))
	draw_rect(Rect2(left, bottom_row - BAR_HEIGHT * 0.4, width, BAR_HEIGHT * 0.8), DIM)
	draw_rect(Rect2(left, bottom_row - BAR_HEIGHT * 0.4, width * stamina_share, BAR_HEIGHT * 0.8), stamina_colour())


func _draw_panel() -> void:
	var w: float = size.x
	var h: float = size.y
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2(CUT, 0.0),
			Vector2(w, 0.0),
			Vector2(w, h - CUT),
			Vector2(w - CUT, h),
			Vector2(0.0, h),
			Vector2(0.0, CUT)
		]
	)
	draw_colored_polygon(points, PANEL)
	points.append(points[0])
	draw_polyline(points, LINE, 1.5, true)


func _draw_segments(left: float, top: float, width: float) -> void:
	var segment: float = (width - GAP * (SEGMENTS - 1)) / SEGMENTS
	var filled: float = filled_segments()
	var tint: Color = health_colour()
	for i: int in SEGMENTS:
		var x: float = left + i * (segment + GAP)
		draw_rect(Rect2(x, top, segment, BAR_HEIGHT), DIM)
		var share: float = clampf(filled - i, 0.0, 1.0)
		if share > 0.0:
			draw_rect(Rect2(x, top, segment * share, BAR_HEIGHT), tint)


func _draw_cross(centre: Vector2) -> void:
	var radius: float = ICON * 0.5
	draw_arc(centre, radius, 0.0, TAU, 32, TEXT, 2.0, true)
	draw_rect(Rect2(centre + Vector2(-2.0, -radius * 0.6), Vector2(4.0, radius * 1.2)), TEXT)
	draw_rect(Rect2(centre + Vector2(-radius * 0.6, -2.0), Vector2(radius * 1.2, 4.0)), TEXT)


func _draw_runner(centre: Vector2) -> void:
	var s: float = ICON * 0.5
	draw_circle(centre + Vector2(s * 0.35, -s * 0.8), s * 0.22, TEXT)
	var hip: Vector2 = centre + Vector2(-s * 0.1, s * 0.15)
	var neck: Vector2 = centre + Vector2(s * 0.2, -s * 0.45)
	draw_line(hip, neck, TEXT, 2.0, true)
	draw_line(neck, centre + Vector2(s * 0.7, -s * 0.05), TEXT, 2.0, true)
	draw_line(neck, centre + Vector2(-s * 0.45, -s * 0.2), TEXT, 2.0, true)
	draw_line(hip, centre + Vector2(s * 0.5, s * 0.9), TEXT, 2.0, true)
	draw_line(hip, centre + Vector2(-s * 0.7, s * 0.7), TEXT, 2.0, true)


func _on_player_spawned(spawned: Player) -> void:
	if player == null and spawned.is_multiplayer_authority():
		player = spawned


func _on_health_changed(changed: Player, current: float, maximum: float) -> void:
	if changed != player:
		return
	health_share = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	queue_redraw()

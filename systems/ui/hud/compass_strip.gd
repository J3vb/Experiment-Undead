## Top-centre compass strip from the concept art (docs/design/concepts/screens/hud_concept_2.jpg):
## ticks every TICK_STEP degrees and N / NE / E ... letters across a WINDOW-degree view of the
## local player's heading. North is world -Z. Hidden, like the round counter, until a round
## has started (or a late joiner lands in a later break).
class_name CompassStrip
extends Control

const WINDOW: float = 120.0
const TICK_STEP: float = 15.0
const REDRAW_STEP: float = 0.2
const FONT_SIZE: int = 18
const TEXT: Color = Color("e6ecec")
const LETTERS: PackedStringArray = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

var player: Player
var heading: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	Events.player_spawned.connect(_on_player_spawned)
	Events.round_started.connect(func(_round: int, _count: int) -> void: visible = true)
	Events.intermission_started.connect(
		func(next_round: int, _duration: float) -> void: visible = visible or next_round > 1
	)


## Compass heading in degrees, 0 to 360, for a look direction: 0 = north (-Z), 90 = east (+X).
static func heading_for(forward: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(forward.x, -forward.z)), 360.0)


## Screen x of a compass bearing for the current heading, or NAN when it is outside the window.
func bearing_x(bearing: float) -> float:
	var offset: float = fposmod(bearing - heading + 180.0, 360.0) - 180.0
	if absf(offset) > WINDOW * 0.5:
		return NAN
	return size.x * 0.5 + offset * size.x / WINDOW


func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not visible:
		return
	var now: float = heading_for(-player.camera.global_basis.z)
	if absf(fposmod(now - heading + 180.0, 360.0) - 180.0) >= REDRAW_STEP:
		heading = now
		queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var line_y: float = size.y - 6.0
	draw_line(Vector2(0.0, line_y), Vector2(size.x, line_y), Color(TEXT, 0.35), 1.0)
	var bearing: float = 0.0
	while bearing < 360.0:
		var x: float = bearing_x(bearing)
		if not is_nan(x):
			var fade: float = 1.0 - absf(x - size.x * 0.5) / (size.x * 0.5)
			var tint: Color = Color(TEXT, clampf(fade * 1.6, 0.0, 1.0))
			var major: bool = is_zero_approx(fmod(bearing, 45.0))
			draw_line(Vector2(x, line_y), Vector2(x, line_y - (10.0 if major else 5.0)), tint, 1.5)
			if major:
				var letter: String = LETTERS[int(bearing / 45.0)]
				var width: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
				draw_string(
					font, Vector2(x - width * 0.5, FONT_SIZE), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, tint
				)
		bearing += TICK_STEP
	draw_line(Vector2(size.x * 0.5, line_y + 2.0), Vector2(size.x * 0.5, line_y - 14.0), TEXT, 2.0)


func _on_player_spawned(spawned: Player) -> void:
	if player == null and spawned.is_multiplayer_authority():
		player = spawned

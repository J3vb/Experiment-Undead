## Bottom-right HUD slot for the lethal (ui-hud.md screen 10): frag icon, count and key,
## right-aligned above the gun name. Dims at 0 and turns warning orange while cooking.
## Reads the local player's GrenadeThrower, whose count the server sends in the state snapshot.
class_name GrenadeSlot
extends Control

const TEXT: Color = Color("e8ece6")
const WARNING: Color = Color("ff8a1c")
## Panel colour from look-rules.md.
const BODY: Color = Color(0.043, 0.059, 0.063, 0.85)
const EMPTY_ALPHA: float = 0.35
const FONT_SIZE: int = 22
const ICON_RADIUS: float = 10.0
const GAP: float = 10.0

var player: Player
var shown_count: int = -1
var shown_cooking: bool = false
var key_text: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, 36.0)
	key_text = "[%s]" % Settings.key_name(&"lethal")
	Settings.changed.connect(_on_setting_changed)
	Events.player_spawned.connect(_on_player_spawned)


func dimmed() -> bool:
	return shown_count <= 0


func _process(_delta: float) -> void:
	var thrower: GrenadeThrower = player.grenades if is_instance_valid(player) else null
	var count: int = thrower.count if thrower else 0
	var cooking: bool = thrower.cooking if thrower else false
	if count != shown_count or cooking != shown_cooking:
		shown_count = count
		shown_cooking = cooking
		modulate.a = EMPTY_ALPHA if dimmed() else 1.0
		queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var tint: Color = WARNING if shown_cooking else TEXT
	var baseline: float = size.y * 0.5 + FONT_SIZE * 0.35
	var right: float = size.x
	var key_width: float = font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(right - key_width, baseline), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT)
	right -= key_width + GAP
	var count_text: String = "x%d" % maxi(shown_count, 0)
	var count_width: float = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(
		font, Vector2(right - count_width, baseline), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, tint
	)
	right -= count_width + GAP + ICON_RADIUS
	_draw_frag(Vector2(right, size.y * 0.5 + 2.0), tint)


func _draw_frag(centre: Vector2, tint: Color) -> void:
	draw_circle(centre, ICON_RADIUS, BODY)
	draw_arc(centre, ICON_RADIUS, 0.0, TAU, 24, tint, 2.0, true)
	draw_rect(Rect2(centre + Vector2(-3.0, -ICON_RADIUS - 5.0), Vector2(6.0, 5.0)), tint)
	draw_line(centre + Vector2(3.0, -ICON_RADIUS - 3.0), centre + Vector2(ICON_RADIUS, -2.0), tint, 2.0)


func _on_player_spawned(spawned: Player) -> void:
	if player == null and spawned.is_multiplayer_authority():
		player = spawned


func _on_setting_changed(section: StringName, _key: StringName, _value: Variant) -> void:
	if section == &"bindings":
		key_text = "[%s]" % Settings.key_name(&"lethal")
		queue_redraw()

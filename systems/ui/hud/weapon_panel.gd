## Bottom-right HUD panel from the concept art (docs/design/concepts/screens/hud_concept.jpg):
## gun icon, magazine big and reserve small, a divider, then the frag icon and count.
## Ammo arrives through Events.ammo_changed; the frag count is read from the local player's
## GrenadeThrower, whose count the server sends in the state snapshot.
class_name WeaponPanel
extends Control

const PANEL: Color = Color(0.071, 0.102, 0.125, 0.88)
const LINE: Color = Color("2c3b44")
const TEXT: Color = Color("e6ecec")
const DIM: Color = Color("8fa3a8")
const WARN: Color = Color("ff9f1c")
const DANGER: Color = Color("c3201b")
const EMPTY_ALPHA: float = 0.35
const CUT: float = 14.0
const PAD: float = 18.0
const ICON_WIDTH: float = 120.0
const AMMO_LEFT: float = 150.0
const AMMO_WIDTH: float = 104.0
const RESERVE_WIDTH: float = 92.0
const FRAG_WIDTH: float = 78.0
const FRAG_RADIUS: float = 10.0
const KEY_FONT_SIZE: int = 14

var player: Player
var shown_count: int = -1
var shown_cooking: bool = false
var key_text: String = ""
var ammo_label: Label
var reserve_label: Label
var frag_label: Label
var _icon: Texture2D
var _warned: Dictionary[StringName, bool] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(460.0, 80.0)
	ammo_label = _add_label(56, HORIZONTAL_ALIGNMENT_RIGHT)
	reserve_label = _add_label(28, HORIZONTAL_ALIGNMENT_LEFT)
	frag_label = _add_label(26, HORIZONTAL_ALIGNMENT_LEFT)
	reserve_label.add_theme_color_override("font_color", DIM)
	ammo_label.text = "0"
	reserve_label.text = "/ 0"
	key_text = Settings.key_name(&"lethal")
	resized.connect(_layout)
	_layout()
	Settings.changed.connect(_on_setting_changed)
	Events.player_spawned.connect(_on_player_spawned)
	Events.ammo_changed.connect(_on_ammo_changed)
	Events.weapon_switched.connect(_on_weapon_switched)


func dimmed() -> bool:
	return shown_count <= 0


## Text colour for a magazine: red when empty, orange at a quarter or less.
static func ammo_colour(in_mag: int, magazine: int) -> Color:
	if in_mag <= 0:
		return DANGER
	return WARN if in_mag <= magazine / 4 else TEXT


func icon() -> Texture2D:
	return _icon


func _process(_delta: float) -> void:
	var thrower: GrenadeThrower = player.grenades if is_instance_valid(player) else null
	var count: int = thrower.count if thrower else 0
	var cooking: bool = thrower.cooking if thrower else false
	if count != shown_count or cooking != shown_cooking:
		shown_count = count
		shown_cooking = cooking
		frag_label.text = str(maxi(count, 0))
		frag_label.add_theme_color_override("font_color", _frag_tint())
		queue_redraw()


func _draw() -> void:
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
	if _icon:
		var icon_height: float = ICON_WIDTH * _icon.get_height() / maxf(_icon.get_width(), 1.0)
		draw_texture_rect(_icon, Rect2(PAD, (h - icon_height) * 0.5, ICON_WIDTH, icon_height), false, TEXT)
	var divider: float = w - FRAG_WIDTH - 4.0
	draw_line(Vector2(divider, h * 0.22), Vector2(divider, h * 0.78), LINE, 2.0)
	var tint: Color = _frag_tint()
	var centre: Vector2 = Vector2(divider + 22.0, h * 0.52)
	draw_circle(centre, FRAG_RADIUS, Color(PANEL, 1.0))
	draw_arc(centre, FRAG_RADIUS, 0.0, TAU, 24, tint, 2.0, true)
	draw_rect(Rect2(centre + Vector2(-3.0, -FRAG_RADIUS - 5.0), Vector2(6.0, 5.0)), tint)
	draw_line(centre + Vector2(3.0, -FRAG_RADIUS - 3.0), centre + Vector2(FRAG_RADIUS, -2.0), tint, 2.0)
	var font: Font = get_theme_default_font()
	var key_pos: Vector2 = Vector2(w - PAD - 6.0, h - 10.0)
	draw_string(font, key_pos, key_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, KEY_FONT_SIZE, Color(DIM, tint.a))


func _frag_tint() -> Color:
	var tint: Color = WARN if shown_cooking else TEXT
	return Color(tint, EMPTY_ALPHA if dimmed() else 1.0)


func _add_label(font_size: int, align: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"LabelMono"
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _layout() -> void:
	var h: float = size.y
	ammo_label.position = Vector2(AMMO_LEFT, 0.0)
	ammo_label.size = Vector2(AMMO_WIDTH, h)
	reserve_label.position = Vector2(AMMO_LEFT + AMMO_WIDTH + 4.0, 8.0)
	reserve_label.size = Vector2(RESERVE_WIDTH, h - 8.0)
	frag_label.position = Vector2(size.x - FRAG_WIDTH + 36.0, 0.0)
	frag_label.size = Vector2(FRAG_WIDTH - 36.0, h)


func _on_player_spawned(spawned: Player) -> void:
	if player == null and spawned.is_multiplayer_authority():
		player = spawned


func _on_ammo_changed(changed: Player, in_mag: int, reserve: int) -> void:
	if changed != player:
		return
	ammo_label.text = str(in_mag)
	reserve_label.text = "/ %d" % reserve
	var magazine: int = player.weapons.current.data.magazine_size if player.weapons.current else in_mag
	ammo_label.add_theme_color_override("font_color", ammo_colour(in_mag, magazine))


func _on_weapon_switched(changed: Player, weapon: Weapon) -> void:
	if changed != player:
		return
	_icon = weapon.data.hud_icon
	if _icon == null and not _warned.has(weapon.data.id):
		_warned[weapon.data.id] = true
		Log.warn(&"hud", &"hud_icon_missing", {"weapon": weapon.data.id})
	queue_redraw()


func _on_setting_changed(section: StringName, _key: StringName, _value: Variant) -> void:
	if section == &"bindings":
		key_text = Settings.key_name(&"lethal")
		queue_redraw()

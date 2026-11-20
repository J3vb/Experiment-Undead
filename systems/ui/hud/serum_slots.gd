## Bottom-left row of Serum slots (docs/design/concepts/screens/hud_serum_slots.png): at least
## MIN_SLOTS squares, a filled one per held Serum in its colour with its icon, the rest dark.
## There is no Serum limit, so the row grows past MIN_SLOTS. Shows the local player only.
class_name SerumSlots
extends Control

const MIN_SLOTS: int = 4
const SLOT: float = 44.0
const GAP: float = 8.0
const ICON_SIZE: float = 28.0
const FONT_SIZE: int = 18
const EMPTY: Color = Color(0.071, 0.102, 0.125, 0.88)
const LINE: Color = Color("2c3b44")
const TEXT: Color = Color("e6ecec")

var player: Player
var shown: Array[SerumData] = []
var _warned: Dictionary[StringName, bool] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(MIN_SLOTS * SLOT + (MIN_SLOTS - 1) * GAP, SLOT)
	Events.player_spawned.connect(_on_player_spawned)
	Events.serum_gained.connect(_on_serum_gained)
	Events.player_health_changed.connect(func(changed: Player, _c: float, _m: float) -> void: _drop_lost(changed))
	Events.player_revived.connect(_drop_lost)


func slot_count() -> int:
	return maxi(MIN_SLOTS, shown.size())


func shown_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for serum: SerumData in shown:
		ids.append(String(serum.id))
	return ids


func _draw() -> void:
	var font: Font = get_theme_default_font()
	for index: int in slot_count():
		var rect: Rect2 = Rect2(index * (SLOT + GAP), 0.0, SLOT, SLOT)
		if index < shown.size():
			_draw_filled(rect, shown[index], font)
		else:
			draw_rect(rect, EMPTY)
			draw_rect(rect, LINE, false, 1.5)


func _draw_filled(rect: Rect2, serum: SerumData, font: Font) -> void:
	draw_rect(rect, serum.badge_colour)
	draw_rect(rect.grow(-4.0), Color(TEXT, 0.8), false, 1.5)
	if serum.icon:
		var half: Vector2 = Vector2.ONE * ICON_SIZE * 0.5
		draw_texture_rect(serum.icon, Rect2(rect.get_center() - half, half * 2.0), false)
		return
	var width: float = font.get_string_size(serum.badge, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var base: Vector2 = rect.get_center() + Vector2(-width * 0.5, FONT_SIZE * 0.35)
	draw_string(font, base, serum.badge, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT)


func _on_player_spawned(spawned: Player) -> void:
	if player == null and spawned.is_multiplayer_authority():
		player = spawned


func _on_serum_gained(gainer: Player, serum: SerumData) -> void:
	if gainer != player:
		return
	for held: SerumData in shown:
		if held.id == serum.id:
			return
	if serum.icon == null and not _warned.has(serum.id):
		_warned[serum.id] = true
		Log.warn(&"hud", &"hud_icon_missing", {"serum": serum.id})
	shown.append(serum)
	_resize()


func _drop_lost(changed: Player) -> void:
	if changed != player:
		return
	var before: int = shown.size()
	for index: int in range(shown.size() - 1, -1, -1):
		if not player.has_serum(shown[index].id):
			shown.remove_at(index)
	if shown.size() != before:
		_resize()


func _resize() -> void:
	custom_minimum_size.x = slot_count() * SLOT + (slot_count() - 1) * GAP
	queue_redraw()

## Field ability square right of the vitals panel (ui-hud.md bottom left, plans/field-abilities.md
## step 3): the ability icon, its key, a dark sweep while it cools down, the seconds left in place
## of the icon under SHOW_SECONDS and a short brass flash when it is ready again. Hidden with no
## ability. Local player only.
class_name AbilityIcon
extends Control

const SIZE: float = 80.0
## Left of the vitals panel's anchor plus its width and a gap; above the same bottom edge.
const LEFT: float = 372.0
const BOTTOM: float = 44.0
const ICON_SIZE: float = 42.0
const KEY_SIZE: int = 16
const SECONDS_SIZE: int = 30
const SHOW_SECONDS: float = 10.0
const FLASH_TIME: float = 0.5
const SHARE_STEP: float = 0.005
const PANEL: Color = Color(0.071, 0.102, 0.125, 0.88)
const LINE: Color = Color("2c3b44")
const TEXT: Color = Color("e6ecec")
const SHADE: Color = Color(0.0, 0.0, 0.0, 0.62)
## Level-up and ready accent (level_up_burst.gd).
const BRASS: Color = Color("e3cf9a")

var player: Player
var key_label: String = ""
## 1 just used, 0 ready.
var cooldown_share: float = 0.0
var seconds_left: int = 0
var flash_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.025
	anchor_right = 0.025
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = LEFT
	offset_right = LEFT + SIZE
	offset_top = -BOTTOM - SIZE
	offset_bottom = -BOTTOM
	visible = false
	key_label = Settings.key_name(&"field_ability")
	Settings.changed.connect(_on_setting_changed)
	Events.player_spawned.connect(_on_player_spawned)


func ability() -> AbilityData:
	return player.abilities.ability if is_instance_valid(player) and player.abilities else null


func _process(delta: float) -> void:
	refresh(delta)


## Reads the player's cooldown; redraws only when what is shown changes.
func refresh(delta: float) -> void:
	var data: AbilityData = ability()
	visible = data != null
	if data == null:
		return
	var left: float = player.abilities.cooldown_left
	var share: float = clampf(left / maxf(player.abilities.full_cooldown(), 0.01), 0.0, 1.0)
	var seconds: int = ceili(left) if left < SHOW_SECONDS else 0
	if share <= 0.0 and cooldown_share > 0.0:
		flash_left = FLASH_TIME
	var flashing: bool = flash_left > 0.0
	flash_left = maxf(flash_left - delta, 0.0)
	if absf(share - cooldown_share) >= SHARE_STEP or (share <= 0.0) != (cooldown_share <= 0.0):
		cooldown_share = share
		queue_redraw()
	elif seconds != seconds_left or flashing:
		queue_redraw()
	seconds_left = seconds


func is_ready() -> bool:
	return cooldown_share <= 0.0


func _draw() -> void:
	var data: AbilityData = ability()
	if data == null:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	draw_rect(rect, PANEL)
	if data.icon and seconds_left == 0:
		var half: Vector2 = Vector2.ONE * ICON_SIZE * 0.5
		var tint: Color = TEXT if is_ready() else Color(TEXT, 0.45)
		draw_texture_rect(data.icon, Rect2(Vector2(SIZE * 0.5, SIZE * 0.42) - half, half * 2.0), false, tint)
	if cooldown_share > 0.0:
		draw_rect(Rect2(0.0, 0.0, SIZE, SIZE * cooldown_share), SHADE)
	var font: Font = get_theme_default_font()
	if seconds_left > 0:
		_draw_centred(font, str(seconds_left), SIZE * 0.42 + SECONDS_SIZE * 0.35, SECONDS_SIZE, TEXT)
	_draw_centred(font, key_label, SIZE - 6.0, KEY_SIZE, Color(TEXT, 0.8))
	draw_rect(rect, LINE, false, 1.5)
	if flash_left > 0.0:
		draw_rect(rect.grow(-1.5), Color(BRASS, flash_left / FLASH_TIME), false, 4.0)


func _draw_centred(font: Font, text: String, baseline: float, font_size: int, colour: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((SIZE - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _on_player_spawned(spawned: Player) -> void:
	if player == null and spawned.is_multiplayer_authority():
		player = spawned


func _on_setting_changed(section: StringName, key: StringName, _value: Variant) -> void:
	if section == &"bindings" and key == &"field_ability":
		key_label = Settings.key_name(&"field_ability")
		queue_redraw()

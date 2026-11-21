## One skill on the Research screen: icon, name and ranks on a dark plate. Owned skills glow
## bio-green (the Fenlight samples), gated ones are grey with a lock line.
class_name SkillTile
extends Button

const PLATE: Color = Color("0d1519e6")
const TEAL: Color = Color("7fd6e0")
const GREEN: Color = Color("8dff3a")
const GREY: Color = Color("5a6a6e")
const TEXT: Color = Color("e2e6e0")

var node: SkillNodeData
## &"locked", &"open" or &"owned"; read by the links and tests.
var state: StringName = &"open"


func _init(skill: SkillNodeData) -> void:
	node = skill
	name = String(skill.id)
	var big: bool = skill.branch_points_needed > 0
	custom_minimum_size = Vector2(240, 92) if big else Vector2(232, 76)
	focus_mode = Control.FOCUS_ALL
	clip_text = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon = skill.icon
	expand_icon = false
	add_theme_constant_override(&"icon_max_width", 48 if big else 40)
	add_theme_constant_override(&"h_separation", 12)
	if skill.icon == null:
		Log.warn(&"ui", &"skill_icon_missing", {"id": String(skill.id)})


## Repaints the tile. locked: the branch gate is not met yet.
func show_rank(rank: int, locked: bool) -> void:
	state = &"locked" if locked else (&"owned" if rank > 0 else &"open")
	var line: String = "%d/%d" % [rank, node.max_ranks]
	if locked:
		line = "Locked (%d)" % node.branch_points_needed
	text = "%s\n%s" % [node.display_name, line]
	var frame: Color = {&"locked": GREY, &"open": TEAL.darkened(0.35), &"owned": GREEN}[state]
	var ink: Color = GREY if locked else (GREEN if rank > 0 else TEXT)
	for style: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		add_theme_stylebox_override(style, _plate(frame, 2, state == &"owned"))
	add_theme_stylebox_override(&"focus", _plate(TEAL, 3, false, true))
	for color: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color"]:
		add_theme_color_override(color, TEXT if not locked else GREY)
	for color: StringName in [&"icon_normal_color", &"icon_hover_color", &"icon_focus_color", &"icon_pressed_color"]:
		add_theme_color_override(color, ink)


static func _plate(frame: Color, width: int, glow: bool, outline_only: bool = false) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT if outline_only else PLATE
	box.draw_center = not outline_only
	box.border_color = frame
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(10)
	if glow:
		box.shadow_color = Color(GREEN, 0.35)
		box.shadow_size = 8
	return box

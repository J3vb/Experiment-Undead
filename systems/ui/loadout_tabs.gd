## The Loadout screen's section tabs from the concept art. Only Weapons and Field Gear have a feature
## yet; the other three show greyed and locked. Tells its parent which open tab was picked.
class_name LoadoutTabs
extends VBoxContainer

signal tab_selected(id: StringName)

const TABS: Array[StringName] = [&"weapons", &"serums", &"perks", &"field_gear", &"customize"]
const OPEN_TABS: Array[StringName] = [&"weapons", &"field_gear"]

var buttons: Array[Button] = []


func _ready() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for id: StringName in TABS:
		var button: Button = Button.new()
		button.text = String(id).replace("_", " ").to_upper()
		button.theme_type_variation = &"MenuBrush"
		button.add_theme_font_size_override("font_size", 18)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = group
		button.set_meta("tab", id)
		if OPEN_TABS.has(id):
			button.pressed.connect(func() -> void: tab_selected.emit(id))
		else:
			button.disabled = true
			button.focus_mode = Control.FOCUS_NONE
			button.tooltip_text = "Coming soon"
		add_child(button)
		_narrow(button)
		buttons.append(button)


## The brush margins sized for the main menu are too wide for a column beside three panels.
func _narrow(button: Button) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		var box: StyleBox = button.get_theme_stylebox(state).duplicate() as StyleBox
		box.content_margin_left = 6.0
		box.content_margin_right = 6.0
		button.add_theme_stylebox_override(state, box)


## Marks `id` as the shown tab without emitting.
func mark(id: StringName) -> void:
	for button: Button in buttons:
		button.set_pressed_no_signal(button.get_meta("tab") == id)


func button_for(id: StringName) -> Button:
	return buttons[TABS.find(id)]


func open_buttons() -> Array[Control]:
	var open: Array[Control] = []
	for id: StringName in OPEN_TABS:
		open.append(button_for(id))
	return open

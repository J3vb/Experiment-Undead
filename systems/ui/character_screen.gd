## Character loadout, fixed stash and a shared item tooltip around a dressed turntable.
class_name CharacterScreen
extends Control

signal closed

const SLOTS: Array[StringName] = [&"primary", &"sidearm", &"vest", &"charm", &"implant"]
const ACCENT: Color = Color("7fd6e0")
const DIM: Color = Color("8fa3a8")

var profile: CharacterProfile
var stash_buttons: Array[Button] = []
var slot_buttons: Array[Button] = []
var selected_stash: int = -1
var selected_slot: StringName = &""
var _comparing: bool = false
var _rotating: bool = false
var _closing: bool = false
var _save_failed: bool = false

@onready var rig: GearRig = %GearRig
@onready var tooltip: ItemTooltip = %ItemTooltip


func _ready() -> void:
	var pad_actions: Dictionary = {
		&"ui_accept": JOY_BUTTON_A,
		&"ui_cancel": JOY_BUTTON_B,
		&"ui_up": JOY_BUTTON_DPAD_UP,
		&"ui_down": JOY_BUTTON_DPAD_DOWN,
		&"ui_left": JOY_BUTTON_DPAD_LEFT,
		&"ui_right": JOY_BUTTON_DPAD_RIGHT
	}
	for action: StringName in pad_actions:
		var binding: InputEventJoypadButton = InputEventJoypadButton.new()
		binding.button_index = pad_actions[action]
		if not InputMap.action_has_event(action, binding):
			InputMap.action_add_event(action, binding)
	_style_controls()
	_build_buttons()
	_wire_focus()
	for filter: OptionButton in [%Category, %Rarity, %Sort]:
		filter.item_selected.connect(func(_index: int) -> void: _refresh())
	%Preview.gui_input.connect(_preview_input)
	%Back.pressed.connect(_close)


func open(character: CharacterProfile) -> void:
	profile = character
	_closing = false
	_save_failed = false
	_comparing = false
	tooltip.set_comparing(false)
	%Back.text = "Back"
	show()
	_refresh()
	if visible_stash_indices().is_empty():
		slot_buttons[0].grab_focus()
	else:
		stash_buttons[0].grab_focus()


func _style_controls() -> void:
	theme = theme.duplicate() as Theme
	theme.set_constant("outline_size", "Label", 0)
	theme.set_color("font_shadow_color", "Label", Color.TRANSPARENT)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color("121a20") if state == "normal" else Color("1a252d")
		box.set_border_width_all(1 if state != "focus" else 2)
		box.border_color = Color("2c3b44") if state == "normal" else ACCENT
		box.content_margin_left = 8.0
		box.content_margin_right = 8.0
		box.content_margin_top = 6.0
		box.content_margin_bottom = 6.0
		if state == "focus":
			box.bg_color = Color.TRANSPARENT
		theme.set_stylebox(state, "Button", box)
	theme.set_color("font_color", "Button", Color("e6ecec"))
	theme.set_color("font_color", "Label", Color("e6ecec"))


func _build_buttons() -> void:
	for slot: StringName in SLOTS:
		var button: Button = Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.set_meta("slot", slot)
		button.add_theme_font_size_override("font_size", 20)
		button.mouse_entered.connect(_inspect.bind(-1, slot))
		button.focus_entered.connect(_inspect.bind(-1, slot))
		button.pressed.connect(_inspect.bind(-1, slot))
		button.gui_input.connect(_item_input.bind(button))
		%Slots.add_child(button)
		slot_buttons.append(button)
	for cell: int in CharacterProfile.STASH_SIZE:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(48, 66)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 20)
		button.set_meta("stash_index", -1)
		button.set_meta("cell", cell)
		button.mouse_entered.connect(_inspect_button.bind(button))
		button.focus_entered.connect(_inspect_button.bind(button))
		button.pressed.connect(_inspect_button.bind(button))
		button.gui_input.connect(_item_input.bind(button))
		%Grid.add_child(button)
		stash_buttons.append(button)


func _wire_focus() -> void:
	var order: Array[Control] = []
	order.assign(slot_buttons)
	order.append_array([%Category, %Rarity, %Sort])
	order.append_array(stash_buttons)
	order.append(%Back)
	for index: int in order.size():
		order[index].focus_next = order[index].get_path_to(order[(index + 1) % order.size()])
		order[index].focus_previous = order[index].get_path_to(order[posmod(index - 1, order.size())])
	for cell: int in stash_buttons.size():
		var button: Button = stash_buttons[cell]
		button.focus_neighbor_left = button.get_path_to(
			slot_buttons[mini(cell / 10, 4)] if cell % 10 == 0 else stash_buttons[cell - 1]
		)
		button.focus_neighbor_right = button.get_path_to(%Back if cell % 10 == 9 else stash_buttons[cell + 1])
		button.focus_neighbor_top = button.get_path_to(%Sort if cell < 10 else stash_buttons[cell - 10])
		button.focus_neighbor_bottom = button.get_path_to(%Back if cell >= 50 else stash_buttons[cell + 10])
	for index: int in slot_buttons.size():
		var button: Button = slot_buttons[index]
		button.focus_neighbor_top = button.get_path_to(%Back if index == 0 else slot_buttons[index - 1])
		button.focus_neighbor_bottom = button.get_path_to(%Back if index == 4 else slot_buttons[index + 1])
		button.focus_neighbor_right = button.get_path_to(stash_buttons[index * 10])
	%Category.focus_neighbor_bottom = %Category.get_path_to(%Sort)
	%Rarity.focus_neighbor_bottom = %Rarity.get_path_to(%Sort)
	%Sort.focus_neighbor_bottom = %Sort.get_path_to(stash_buttons[0])
	%Back.focus_neighbor_top = %Back.get_path_to(stash_buttons[59])


func visible_stash_indices() -> Array[int]:
	var indices: Array[int] = []
	if profile == null:
		return indices
	for index: int in profile.stash.size():
		var item: Dictionary = profile.stash[index]
		if item.is_empty():
			continue
		var base: StringName = StringName(item.get("base", ""))
		var weapon: bool = Content.ids(&"weapons").has(base)
		var gear: bool = Inventory.slot_for(item) in [&"vest", &"charm", &"implant"]
		if (%Category.selected == 1 and not weapon) or (%Category.selected == 2 and not gear):
			continue
		if %Rarity.selected > 0 and item.get("rar", "common") != ItemRoller.RARITIES[%Rarity.selected - 1]:
			continue
		indices.append(index)
	indices.sort_custom(_comes_before)
	return indices


func _comes_before(left: int, right: int) -> bool:
	if %Sort.selected == 2:
		var left_order: int = int(profile.stash[left].get("acquired", left))
		var right_order: int = int(profile.stash[right].get("acquired", right))
		return left_order > right_order if left_order != right_order else left > right
	var a: Dictionary = profile.stash[left]
	var b: Dictionary = profile.stash[right]
	var a_rarity: int = ItemRoller.RARITIES.find(StringName(a.get("rar", "common")))
	var b_rarity: int = ItemRoller.RARITIES.find(StringName(b.get("rar", "common")))
	var a_level: int = int(a.get("ilvl", 1))
	var b_level: int = int(b.get("ilvl", 1))
	if %Sort.selected == 1 and a_level != b_level:
		return a_level > b_level
	if a_rarity != b_rarity:
		return a_rarity > b_rarity
	return a_level > b_level if a_level != b_level else left > right


func _refresh() -> void:
	if profile == null:
		return
	%Name.text = profile.display_name
	%Level.text = "Level %d" % profile.level
	var indices: Array[int] = visible_stash_indices()
	var count: int = 0
	for item: Dictionary in profile.stash:
		count += 0 if item.is_empty() else 1
	%Count.text = "Stash %d / 60" % count
	for index: int in SLOTS.size():
		var item: Dictionary = profile.loadout[SLOTS[index]]
		_paint_button(slot_buttons[index], item)
		slot_buttons[index].text = "%s: %s" % [String(SLOTS[index]).capitalize(), _item_name(item)]
	for cell: int in stash_buttons.size():
		var index: int = indices[cell] if cell < indices.size() else -1
		stash_buttons[cell].set_meta("stash_index", index)
		_paint_button(stash_buttons[cell], profile.stash[index] if index >= 0 else {})
	rig.apply(LookBuilder.from_equipped(profile.loadout))
	%Status.text = "No items match these filters" if indices.is_empty() and count > 0 else "Select an item to inspect"
	_inspect(indices[0] if not indices.is_empty() else -1, &"")
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is Button and (focused.has_meta("slot") or focused.has_meta("stash_index")):
		_inspect_button(focused as Button)


func _paint_button(button: Button, item: Dictionary) -> void:
	var rarity: StringName = StringName(item.get("rar", "common"))
	var rank: int = maxi(ItemRoller.RARITIES.find(rarity), 0)
	var box: StyleBoxFlat = theme.get_stylebox("normal", "Button").duplicate() as StyleBoxFlat
	box.border_color = Color("2c3b44")
	if not item.is_empty():
		var data: RarityData = Content.get_item(&"loot", ItemRoller.RARITIES[rank]) as RarityData
		box.border_color = data.colour
	button.add_theme_stylebox_override("normal", box)
	button.text = ""
	if not item.is_empty():
		button.text = (
			"%s\n%s%d" % [_item_name(item).left(2).to_upper(), ItemTooltip.SHAPES[rank], int(item.get("ilvl", 1))]
		)


func _item_name(item: Dictionary) -> String:
	if item.is_empty():
		return "Empty"
	var base: StringName = StringName(item.get("base", ""))
	if Content.ids(&"weapons").has(base):
		return Content.weapon(base).display_name
	if Content.ids(&"loot").has(base):
		var gear: GearBaseData = Content.get_item(&"loot", base) as GearBaseData
		if gear != null:
			return gear.display_name
	return String(base).capitalize() if GearVisual.SCENES.has(base) else "Unknown item"


func _inspect_button(button: Button) -> void:
	_inspect(int(button.get_meta("stash_index", -1)), StringName(button.get_meta("slot", &"")))


func _inspect(index: int, slot: StringName) -> void:
	selected_stash = index
	selected_slot = slot
	if profile == null:
		return
	var item: Dictionary = profile.stash[index] if index >= 0 else profile.loadout.get(slot, {})
	var compare_slot: StringName = Inventory.slot_for(item)
	if compare_slot.is_empty():
		compare_slot = StringName(String(item.get("base", "")).get_slice("_", 0))
	tooltip.show_item(item, profile.loadout.get(compare_slot, {}))


func _item_input(event: InputEvent, button: Button) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and event.double_click
	):
		_inspect_button(button)
		_activate_selected()
		get_viewport().set_input_as_handled()


func _activate_selected() -> void:
	if profile == null:
		return
	var moved: bool = (
		Inventory.equip(profile, selected_stash) if selected_stash >= 0 else Inventory.unequip(profile, selected_slot)
	)
	if moved:
		_refresh()
	else:
		%Status.text = "Cannot move item: check its slot and free stash space"


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or profile == null:
		return
	if event is InputEventKey and event.echo:
		return
	_update_hints(event)
	_compare_input(event)
	if event is InputEventMouseButton and not event.pressed:
		_rotating = false
	for filter: OptionButton in [%Category, %Rarity, %Sort]:
		if filter.get_popup().visible:
			return
	var escape: bool = event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE
	if event.is_action_pressed(&"ui_cancel") or escape:
		_close()
		get_viewport().set_input_as_handled()
	elif _equip_input(event):
		if event.is_action_pressed(&"ui_accept"):
			_inspect_button(get_viewport().gui_get_focus_owner() as Button)
		_activate_selected()
		get_viewport().set_input_as_handled()


func _compare_input(event: InputEvent) -> void:
	if event is InputEventKey and (event.keycode == KEY_SHIFT or event.physical_keycode == KEY_SHIFT):
		_comparing = event.pressed
		tooltip.set_comparing(_comparing)
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_X and event.pressed:
		_comparing = not _comparing
		tooltip.set_comparing(_comparing)


func _equip_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E or event.keycode == KEY_E:
			return true
	var focused: Control = get_viewport().gui_get_focus_owner()
	return (
		event.is_action_pressed(&"ui_accept")
		and focused != null
		and (focused.has_meta("slot") or focused.has_meta("stash_index"))
	)


func _update_hints(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		%Hints.text = "A Equip / unequip    X Compare    B Back"
	elif event is InputEventKey or event is InputEventMouse:
		%Hints.text = "E Equip / unequip    Shift Compare    Esc Back"


func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_rotating = event.pressed
	if event is InputEventMouseMotion and _rotating:
		%Turntable.rotation.y += event.relative.x * 0.01


func _close() -> void:
	if profile == null or _closing:
		return
	var error: Error = profile.save()
	if error != OK and not _save_failed:
		_save_failed = true
		%Status.text = "Could not save (%s). Back again closes without saving." % error_string(error)
		%Back.text = "Close without saving"
		return
	_closing = true
	hide()
	closed.emit()

## One settings page built from SettingData rows: label, control and a hint line per row, live to Settings.
class_name SettingsPage
extends VBoxContainer

## A display mode or resolution row changed; the screen asks the player to keep it.
signal confirm_needed(row: SettingData, old_value: Variant)

## Page id to load from content/settings; empty when rows are given with build().
@export var page: StringName = &""

var rows: Array[SettingData] = []
var _controls: Dictionary[SettingData, Control] = {}
var _lines: Dictionary[SettingData, Array] = {}
var _dragging: HSlider


## Rows of one page from content/settings, in their order.
static func load_rows(page_id: StringName) -> Array[SettingData]:
	var found: Array[SettingData] = []
	for id: StringName in Content.ids(&"settings"):
		var row: SettingData = Content.get_item(&"settings", id) as SettingData
		if row and row.page == page_id:
			found.append(row)
	found.sort_custom(func(a: SettingData, b: SettingData) -> bool: return a.order < b.order)
	return found


func _ready() -> void:
	add_theme_constant_override(&"separation", 16)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if page != &"" and rows.is_empty():
		build(load_rows(page))
	Settings.changed.connect(_on_setting_changed)
	refresh()


func build(new_rows: Array[SettingData]) -> void:
	for row: SettingData in new_rows:
		var defaults: Dictionary = Settings.DEFAULTS.get(row.section, {})
		if not defaults.has(row.key):
			Log.warn(&"settings", &"row_unknown_key", {"section": row.section, "key": row.key})
			continue
		rows.append(row)
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 16)
		var label: Label = Label.new()
		label.text = row.label
		label.custom_minimum_size = Vector2(450, 40)
		line.add_child(label)
		var control: Control = _make_control(row)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(control)
		_controls[row] = control
		if row.kind == &"slider":
			var number: Label = Label.new()
			number.name = "Number"
			number.custom_minimum_size = Vector2(110, 40)
			line.add_child(number)
		add_child(line)
		var hint: Label = Label.new()
		hint.theme_type_variation = &"LabelDim"
		hint.text = row.hint
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(hint)
		_lines[row] = [line, hint]


## Shows only rows whose label or hint holds the text (any case); returns how many match.
func filter(text: String) -> int:
	var matches: int = 0
	for row: SettingData in rows:
		var shown: bool = text.is_empty() or row.label.containsn(text) or row.hint.containsn(text)
		for node: Control in _lines[row]:
			node.visible = shown
		matches += int(shown)
	return matches


## Puts every row of this page back to its default.
func reset_defaults() -> void:
	for row: SettingData in rows:
		Settings.set_value(row.section, row.key, Settings.DEFAULTS[row.section][row.key])


func control_for(key: StringName) -> Control:
	for row: SettingData in rows:
		if row.key == key:
			return _controls[row]
	return null


func _make_control(row: SettingData) -> Control:
	if row.kind == &"slider":
		var slider: HSlider = HSlider.new()
		slider.min_value = row.min_value * row.display_scale
		slider.max_value = row.max_value * row.display_scale
		slider.step = row.step * row.display_scale
		slider.custom_minimum_size = Vector2(220, 40)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_slider_moved.bind(row, slider))
		slider.drag_started.connect(func() -> void: _dragging = slider)
		slider.drag_ended.connect(_on_slider_released.bind(row, slider))
		return slider
	if row.kind == &"choice":
		var option: OptionButton = OptionButton.new()
		for text: String in row.options:
			option.add_item(text)
		for index: int in row.locked_options:
			option.set_item_disabled(index, true)
		option.item_selected.connect(func(index: int) -> void: _write(row, _choice_value(row, index)))
		return option
	if row.kind == &"number":
		var spin: SpinBox = SpinBox.new()
		spin.min_value = row.min_value
		spin.max_value = row.max_value
		spin.step = maxf(row.step, 1.0)
		spin.value_changed.connect(func(value: float) -> void: _write(row, int(value)))
		return spin
	var check: CheckBox = CheckBox.new()
	check.toggled.connect(func(value: bool) -> void: _write(row, value))
	return check


func _on_slider_moved(value: float, row: SettingData, slider: HSlider) -> void:
	if row.apply_on_release and _dragging == slider:
		(slider.get_node("../Number") as Label).text = _number_text(row, value)
	else:
		_write(row, value / row.display_scale)


func _on_slider_released(_changed: bool, row: SettingData, slider: HSlider) -> void:
	_dragging = null
	_write(row, slider.value / row.display_scale)


func _write(row: SettingData, value: Variant) -> void:
	var old: Variant = Settings.get_value(row.section, row.key)
	Settings.set_value(row.section, row.key, value)
	if row.needs_confirm and Settings.get_value(row.section, row.key) != old:
		confirm_needed.emit(row, old)


func _choice_value(row: SettingData, index: int) -> Variant:
	if row.option_values.is_empty():
		return index
	var text: String = row.option_values[index]
	if Settings.DEFAULTS[row.section][row.key] is int:
		return int(text)
	return text


func _choice_index(row: SettingData, value: Variant) -> int:
	if row.option_values.is_empty():
		return int(value)
	return row.option_values.find(str(value))


## FSR 2 runs its own TAA, so the anti-aliasing row shows TAA while it is on.
func _shown_value(row: SettingData) -> Variant:
	var value: Variant = Settings.get_value(row.section, row.key)
	if row.section == &"graphics" and row.key == &"aa":
		return Graphics.effective_aa({&"aa": value, &"upscaler": Settings.get_value(&"graphics", &"upscaler")})
	return value


func refresh() -> void:
	for row: SettingData in rows:
		var value: Variant = _shown_value(row)
		var control: Control = _controls[row]
		if control is HSlider:
			var shown: float = float(value) * row.display_scale
			(control as HSlider).set_value_no_signal(shown)
			var number: Label = control.get_node("../Number") as Label
			number.text = _number_text(row, shown)
		elif control is OptionButton:
			(control as OptionButton).select(_choice_index(row, value))
		elif control is SpinBox:
			(control as SpinBox).set_value_no_signal(float(value))
		else:
			var check: CheckBox = control as CheckBox
			check.set_pressed_no_signal(bool(value))
			check.text = "On" if check.button_pressed else "Off"


func _number_text(row: SettingData, shown: float) -> String:
	if row.display_scale == 100.0:
		return "%d %%" % roundi(shown)
	var step: float = row.step * row.display_scale
	return str(roundi(shown)) if step >= 1.0 else str(snappedf(shown, step))


func _on_setting_changed(_section: StringName, _key: StringName, _value: Variant) -> void:
	refresh()

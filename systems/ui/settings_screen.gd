## In-game preferences, applied and saved immediately by Settings.
class_name SettingsScreen
extends Control

signal closed

const SLIDERS: Dictionary = {
	&"mouse_sensitivity": [&"controls", 1.0],
	&"ads_sensitivity_multiplier": [&"controls", 1.0],
	&"fov": [&"video", 1.0],
	&"master_volume": [&"audio", 100.0],
	&"music_volume": [&"audio", 100.0],
	&"sfx_volume": [&"audio", 100.0],
}
const CHECKS: Dictionary = {&"invert_y": &"controls"}
const CHECK_LABELS: Dictionary = {&"invert_y": "Invert Y"}
const KEEP_SECONDS: int = 15

var fade: Tween

var _keep_row: SettingData
var _keep_old: Variant
var _keep_left: int = 0


func _ready() -> void:
	var menu_theme: Theme = theme
	theme = preload("res://systems/ui/theme.tres").duplicate() as Theme
	theme.merge_with(menu_theme)
	theme.default_font_size = 24
	for key: StringName in SLIDERS:
		var slider: HSlider = get_node("%" + key) as HSlider
		slider.value_changed.connect(_on_slider_changed.bind(key))
	for key: StringName in CHECKS:
		var check: CheckBox = get_node("%" + key) as CheckBox
		check.toggled.connect(func(value: bool) -> void: Settings.set_value(CHECKS[key], key, value))
	%Page.confirm_needed.connect(_ask_keep)
	%KeepDialog.confirmed.connect(_keep)
	%KeepDialog.canceled.connect(_revert_keep)
	%KeepTimer.timeout.connect(_tick_keep)
	%Reset.pressed.connect(Settings.reset_to_defaults)
	%Back.pressed.connect(_close)
	Settings.changed.connect(_on_setting_changed)
	_refresh()
	if is_visible_in_tree():
		_fade_in()
		($Margin/Box/Tabs as TabContainer).get_tab_bar().grab_focus()


func _fade_in() -> void:
	modulate.a = 0.0
	position.x = 12.0
	fade = create_tween().set_parallel(true)
	fade.tween_property(self, "modulate:a", 1.0, 0.12)
	fade.tween_property(self, "position:x", 0.0, 0.12)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _keep_row != null and event.is_action_pressed(&"ui_cancel"):
		_revert_keep()
		get_viewport().set_input_as_handled()
	elif _keep_row != null:
		return
	elif event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


## Freed with the whole stack (a co-op match ending) while asking: an unconfirmed display change goes back.
func _exit_tree() -> void:
	_revert_keep()


func _close() -> void:
	_revert_keep()
	hide()
	closed.emit()


func _on_slider_changed(value: float, key: StringName) -> void:
	Settings.set_value(SLIDERS[key][0], key, value / float(SLIDERS[key][1]))


## Display mode and resolution changes go back by themselves unless the player keeps them in time.
func _ask_keep(row: SettingData, old_value: Variant) -> void:
	_keep_old = old_value
	_keep_row = row
	_keep_left = KEEP_SECONDS
	_show_keep_text()
	%KeepDialog.popup_centered.call_deferred(Vector2i(640, 0))
	%KeepTimer.start(1.0)


func _tick_keep() -> void:
	if _keep_row == null:
		return
	_keep_left -= 1
	if _keep_left <= 0:
		_revert_keep()
	else:
		_show_keep_text()


func _show_keep_text() -> void:
	%KeepDialog.dialog_text = "%s changed. Going back in %d s." % [_keep_row.label, _keep_left]


func _keep() -> void:
	_keep_row = null
	%KeepTimer.stop()
	%KeepDialog.hide()


func _revert_keep() -> void:
	if _keep_row == null:
		return
	var row: SettingData = _keep_row
	_keep()
	Settings.set_value(row.section, row.key, _keep_old)


func _on_setting_changed(_section: StringName, _key: StringName, _value: Variant) -> void:
	_refresh()


func _refresh() -> void:
	for key: StringName in SLIDERS:
		var slider: HSlider = get_node("%" + key) as HSlider
		var value: float = float(Settings.get_value(SLIDERS[key][0], key)) * float(SLIDERS[key][1])
		slider.set_value_no_signal(value)
		var display: Label = slider.get_node("../Number") as Label
		display.text = ("%d %%" % roundi(value)) if SLIDERS[key][0] == &"audio" else str(value)
	for key: StringName in CHECKS:
		var check: CheckBox = get_node("%" + key) as CheckBox
		check.set_pressed_no_signal(bool(Settings.get_value(CHECKS[key], key)))
		check.text = "%s   [%s]" % [CHECK_LABELS[key], "On" if check.button_pressed else "Off"]

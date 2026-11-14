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
const CHECKS: Dictionary = {&"invert_y": &"controls", &"vsync": &"video", &"show_fps": &"video"}
const FPS: Array[int] = [60, 120, 144, 165, 240, 0]


func _ready() -> void:
	theme = theme.duplicate() as Theme
	theme.default_font_size = 24
	for key: StringName in SLIDERS:
		var slider: HSlider = get_node("%" + key) as HSlider
		slider.value_changed.connect(_on_slider_changed.bind(key))
	for key: StringName in CHECKS:
		var check: CheckBox = get_node("%" + key) as CheckBox
		check.toggled.connect(func(value: bool) -> void: Settings.set_value(CHECKS[key], key, value))
	%max_fps.item_selected.connect(_on_fps_selected)
	%Reset.pressed.connect(Settings.reset_to_defaults)
	%Back.pressed.connect(_close)
	Settings.changed.connect(_on_setting_changed)
	_refresh()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"pause"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	hide()
	closed.emit()


func _on_slider_changed(value: float, key: StringName) -> void:
	Settings.set_value(SLIDERS[key][0], key, value / float(SLIDERS[key][1]))


func _on_fps_selected(index: int) -> void:
	Settings.set_value(&"video", &"max_fps", FPS[index])


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
	%max_fps.select(FPS.find(int(Settings.get_value(&"video", &"max_fps"))))

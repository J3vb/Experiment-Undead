## Builds settings rows from SettingData: control per kind, hints, scaled sliders, string choices and FSR 2 TAA.
extends GutTest

const PATH: String = "user://test_settings_page.cfg"

var _old_path: String
var _old_values: Dictionary


func before_each() -> void:
	_old_path = Settings.config_path
	_old_values = Settings._values.duplicate(true)
	Settings.config_path = PATH
	Settings.reset_to_defaults()


func after_each() -> void:
	Settings._values = _old_values
	Settings._apply_all()
	Settings.config_path = _old_path
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _row(section: StringName, key: StringName, kind: StringName, hint: String) -> SettingData:
	var row: SettingData = SettingData.new()
	row.page = &"test"
	row.section = section
	row.key = key
	row.kind = kind
	row.label = String(key)
	row.hint = hint
	return row


func _page(rows: Array[SettingData]) -> SettingsPage:
	var page: SettingsPage = SettingsPage.new()
	page.build(rows)
	add_child_autofree(page)
	return page


func test_three_rows_get_their_controls_and_hints() -> void:
	var slider: SettingData = _row(&"audio", &"music_volume", &"slider", "Music hint")
	slider.display_scale = 100.0
	var choice: SettingData = _row(&"graphics", &"shadows", &"choice", "Shadow hint")
	choice.options = PackedStringArray(["Low", "Medium", "High", "Ultra"])
	var toggle: SettingData = _row(&"graphics", &"glow", &"toggle", "Glow hint")
	var page: SettingsPage = _page([slider, choice, toggle] as Array[SettingData])
	assert_eq(page.rows.size(), 3)
	assert_true(page.control_for(&"music_volume") is HSlider)
	assert_true(page.control_for(&"shadows") is OptionButton)
	assert_true(page.control_for(&"glow") is CheckBox)
	var hints: Array[String] = []
	for child: Node in page.get_children():
		if child is Label:
			hints.append((child as Label).text)
	assert_eq(hints, ["Music hint", "Shadow hint", "Glow hint"] as Array[String])
	assert_eq((page.control_for(&"shadows") as OptionButton).selected, 2)
	assert_true((page.control_for(&"glow") as CheckBox).button_pressed)


func test_slider_writes_the_scaled_value_and_shows_a_percent() -> void:
	var row: SettingData = _row(&"graphics", &"render_scale", &"slider", "hint")
	row.min_value = 0.5
	row.max_value = 1.0
	row.step = 0.05
	row.display_scale = 100.0
	var slider: HSlider = _page([row] as Array[SettingData]).control_for(&"render_scale") as HSlider
	assert_eq(slider.min_value, 50.0)
	assert_eq(slider.value, 100.0)
	slider.value = 75.0
	assert_almost_eq(float(Settings.get_value(&"graphics", &"render_scale")), 0.75, 0.0001)
	assert_eq((slider.get_node("../Number") as Label).text, "75 %")


func test_number_row_saves_a_whole_number() -> void:
	var row: SettingData = _row(&"network", &"last_port", &"number", "hint")
	row.min_value = 1.0
	row.max_value = 64535.0
	row.step = 1.0
	var spin: SpinBox = _page([row] as Array[SettingData]).control_for(&"last_port") as SpinBox
	assert_eq(spin.value, float(Settings.get_value(&"network", &"last_port")))
	spin.value = 24690.0
	assert_eq(Settings.get_value(&"network", &"last_port"), 24690)
	assert_true(Settings.get_value(&"network", &"last_port") is int)


func test_option_values_save_typed_values() -> void:
	var row: SettingData = _row(&"graphics", &"max_fps", &"choice", "hint")
	row.options = PackedStringArray(["60", "Unlimited"])
	row.option_values = PackedStringArray(["60", "0"])
	var option: OptionButton = _page([row] as Array[SettingData]).control_for(&"max_fps") as OptionButton
	assert_eq(option.selected, 1, "default 0 shows Unlimited")
	option.item_selected.emit(0)
	assert_eq(Settings.get_value(&"graphics", &"max_fps"), 60)
	assert_true(Settings.get_value(&"graphics", &"max_fps") is int)


func test_fsr2_shows_taa_on_the_aa_row() -> void:
	var row: SettingData = _row(&"graphics", &"aa", &"choice", "hint")
	row.options = PackedStringArray(["Off", "FXAA", "MSAA 2x", "MSAA 4x", "TAA"])
	var option: OptionButton = _page([row] as Array[SettingData]).control_for(&"aa") as OptionButton
	assert_eq(option.selected, Graphics.Aa.MSAA_4X)
	Settings.set_value(&"graphics", &"upscaler", Graphics.Upscaler.FSR2)
	assert_eq(option.selected, Graphics.Aa.TAA)


func test_unknown_key_is_left_out() -> void:
	var page: SettingsPage = _page([_row(&"graphics", &"no_such_key", &"toggle", "hint")] as Array[SettingData])
	assert_eq(page.rows.size(), 0)
	assert_eq(page.get_child_count(), 0)


func test_confirm_rows_signal_the_old_value() -> void:
	var row: SettingData = _row(&"graphics", &"display_mode", &"choice", "hint")
	row.options = PackedStringArray(["Windowed", "Borderless", "Fullscreen"])
	row.needs_confirm = true
	var page: SettingsPage = _page([row] as Array[SettingData])
	watch_signals(page)
	(page.control_for(&"display_mode") as OptionButton).item_selected.emit(1)
	assert_signal_emitted_with_parameters(page, "confirm_needed", [row, 0])


func test_load_rows_reads_one_page_in_order() -> void:
	var rows: Array[SettingData] = SettingsPage.load_rows(&"graphics")
	assert_gt(rows.size(), 10)
	for index: int in range(1, rows.size()):
		assert_lt(rows[index - 1].order, rows[index].order)
		assert_eq(rows[index].page, &"graphics")


func test_apply_on_release_waits_for_the_drag_to_end() -> void:
	var row: SettingData = _row(&"accessibility", &"text_scale", &"slider", "hint")
	row.min_value = 0.8
	row.max_value = 1.5
	row.step = 0.05
	row.display_scale = 100.0
	row.apply_on_release = true
	var slider: HSlider = _page([row] as Array[SettingData]).control_for(&"text_scale") as HSlider
	slider.drag_started.emit()
	slider.value = 130.0
	assert_eq(Settings.get_value(&"accessibility", &"text_scale"), 1.0, "nothing resizes mid-drag")
	assert_eq((slider.get_node("../Number") as Label).text, "130 %")
	slider.drag_ended.emit(true)
	assert_almost_eq(float(Settings.get_value(&"accessibility", &"text_scale")), 1.3, 0.0001)
	slider.value = 140.0
	assert_almost_eq(float(Settings.get_value(&"accessibility", &"text_scale")), 1.4, 0.0001, "keys apply at once")

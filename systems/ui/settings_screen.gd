## In-game preferences, generated from content/settings rows, applied and saved immediately by Settings.
class_name SettingsScreen
extends Control

signal closed

const KEEP_SECONDS: int = 15

var fade: Tween
var pages: Array[SettingsPage] = []

var _opened: Dictionary[SettingData, Variant] = {}
var _keep_row: SettingData
var _keep_old: Variant
var _keep_left: int = 0


func _ready() -> void:
	var menu_theme: Theme = theme
	theme = preload("res://systems/ui/theme.tres").duplicate() as Theme
	theme.merge_with(menu_theme)
	theme.default_font_size = 24
	for tab: Node in %Tabs.get_children():
		var page: SettingsPage = tab.get_node("Page") as SettingsPage
		pages.append(page)
		page.confirm_needed.connect(_ask_keep)
		for row: SettingData in page.rows:
			_opened[row] = Settings.get_value(row.section, row.key)
	%KeyBindings.get_parent().move_child(%KeyBindings, -1)
	%ComfortPreset.get_parent().move_child(%ComfortPreset, -1)
	%ComfortPresetHint.get_parent().move_child(%ComfortPresetHint, -1)
	%ComfortPreset.pressed.connect(Settings.apply_comfort_preset)
	%Search.text_changed.connect(search)
	%KeepDialog.confirmed.connect(_keep)
	%KeepDialog.canceled.connect(_revert_keep)
	%KeepTimer.timeout.connect(_tick_keep)
	%Revert.pressed.connect(revert)
	%Defaults.pressed.connect(reset_page)
	%Back.pressed.connect(_close)
	if is_visible_in_tree():
		_fade_in()
		(%Tabs as TabContainer).get_tab_bar().grab_focus()


## Fades in with a 12 px slide; reduce motion keeps only the fade.
func _fade_in() -> void:
	modulate.a = 0.0
	fade = create_tween().set_parallel(true)
	fade.tween_property(self, "modulate:a", 1.0, 0.12)
	if not Settings.get_value(&"accessibility", &"reduce_motion"):
		position.x = 12.0
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


## Filters rows on every page by label and hint, and opens the first page with a match if this one has none.
func search(text: String) -> void:
	var tabs: TabContainer = %Tabs as TabContainer
	var first: int = -1
	var current: int = 0
	for index: int in pages.size():
		var matches: int = pages[index].filter(text.strip_edges())
		if matches > 0 and first < 0:
			first = index
		if index == tabs.current_tab:
			current = matches
	for extra: Control in [%KeyBindings, %ComfortPreset, %ComfortPresetHint]:
		extra.visible = text.strip_edges().is_empty()
	if current == 0 and first >= 0:
		tabs.current_tab = first


## Puts back every value from when the screen opened. Key bindings keep their own per-action Reset.
func revert() -> void:
	for row: SettingData in _opened:
		Settings.set_value(row.section, row.key, _opened[row])


## Defaults for the open page only; the Controls page resets the key bindings.
func reset_page() -> void:
	var page: SettingsPage = pages[(%Tabs as TabContainer).current_tab]
	page.reset_defaults()
	if page.is_ancestor_of(%KeyBindings):
		Settings.reset_bindings()


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

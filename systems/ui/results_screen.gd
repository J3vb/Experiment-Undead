## Run results and XP playback; navigation requests go up to the owning HUD.
class_name ResultsScreen
extends Control

signal main_menu_requested
signal restart_requested

const DEFAULT_RULES: XpRules = preload("res://content/progression/xp_rules.tres")
const UI_THEME: Theme = preload("res://systems/ui/results_screen.tres")

var _rules: XpRules = DEFAULT_RULES
var _xp_tween: Tween
var _panel_tween: Tween
var _shown_level: int = 1

@onready var map_time: Label = %MapTime
@onready var round_label: Label = %Round
@onready var kills_label: Label = %Kills
@onready var headshots_label: Label = %Headshots
@onready var points_label: Label = %Points
@onready var exfil_banner: Label = %Exfil
@onready var xp_label: Label = %Xp
@onready var xp_bar: ProgressBar = %XpBar
@onready var level_label: Label = %Level
@onready var level_ups: VBoxContainer = %LevelUps
@onready var main_menu_button: Button = %MainMenu
@onready var restart_button: Button = %Restart


func _ready() -> void:
	theme = preload("res://systems/ui/theme.tres").duplicate() as Theme
	theme.merge_with(UI_THEME)
	main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	$Background.color = get_theme_color("bg_deep", "ResultsScreen")


func show_results(stats: Dictionary, seconds: int = 0, rules: XpRules = DEFAULT_RULES) -> void:
	_rules = rules
	if _xp_tween:
		_xp_tween.kill()
	for row: Node in level_ups.get_children():
		level_ups.remove_child(row)
		row.free()
	map_time.text = "Halcyon Labs · %02d:%02d" % [seconds / 60, seconds % 60]
	round_label.text = str(stats.get("round", 0))
	kills_label.text = _format_number(int(stats.get("kills", 0)))
	headshots_label.text = _format_number(int(stats.get("headshots", 0)))
	points_label.text = _format_number(int(stats.get("points", 0)))
	exfil_banner.visible = bool(stats.get("exfil", false))
	xp_label.text = "XP +%s" % _format_number(int(stats.get("xp", 0)))
	var start: int = int(stats.get("start_total_xp", 0))
	var total: int = int(stats.get("total_xp", start))
	_shown_level = _rules.level_for_total_xp(start)
	_set_display_xp(float(start))
	show()
	main_menu_button.grab_focus()
	_animate_panels()
	_xp_tween = create_tween()
	_xp_tween.tween_method(_set_display_xp, float(start), float(total), 1.5)


func _set_display_xp(total: float) -> void:
	var current: int = floori(total)
	var level: int = _rules.level_for_total_xp(current)
	for gained: int in range(_shown_level + 1, level + 1):
		_add_level_up(gained)
	_shown_level = level
	level_label.text = "LV %d" % level
	var needed: int = _rules.xp_to_next(level)
	xp_bar.max_value = maxf(needed, 1.0)
	xp_bar.value = current - _rules.total_xp_for_level(level) if needed > 0 else 1


func _add_level_up(level: int) -> void:
	var row: VBoxContainer = VBoxContainer.new()
	var title: Label = Label.new()
	title.theme_type_variation = &"LabelXp"
	title.text = "Level up! %d → %d" % [level - 1, level]
	row.add_child(title)
	var points: int = _rules.skill_points_for_level(level) - _rules.skill_points_for_level(level - 1)
	var reward: Label = Label.new()
	reward.theme_type_variation = &"LabelDim"
	reward.text = "+%d skill point%s" % [points, "" if points == 1 else "s"]
	row.add_child(reward)
	level_ups.add_child(row)


func _animate_panels() -> void:
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true)
	for panel: Control in [$StatsPanel, $ProgressPanel]:
		panel.modulate.a = 0.0
		panel.position.y = size.y * 0.25 + 12.0
		_panel_tween.tween_property(panel, "modulate:a", 1.0, 0.12)
		_panel_tween.tween_property(panel, "position:y", size.y * 0.25, 0.12)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	if (
		event.is_action_pressed(&"ui_cancel")
		or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B)
	):
		get_viewport().set_input_as_handled()
		main_menu_requested.emit()
	elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		if main_menu_button.has_focus():
			main_menu_requested.emit()
		elif restart_button.has_focus():
			restart_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"reload") or event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		restart_requested.emit()


func _format_number(value: int) -> String:
	var digits: String = str(value)
	var index: int = digits.length() - 3
	while index > 0:
		digits = digits.insert(index, ",")
		index -= 3
	return digits

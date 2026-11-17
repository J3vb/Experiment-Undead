## Run results and XP playback; GameSession pushes it on game over and answers its navigation requests.
class_name ResultsScreen
extends Control

## Router screen contract. Results never pop: both buttons leave the match, which clears the stack.
@warning_ignore("unused_signal")  # every pushed screen has closed (tests/content/test_screens.gd)
signal closed
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
@onready var loot_title: Label = %LootTitle
@onready var loot_status: Label = %LootStatus
@onready var loot_items: VBoxContainer = %LootItems
@onready var loot_empty: Label = %LootEmpty
@onready var loot_scroll: ScrollContainer = $LootPanel/Box/Scroll
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
	round_label.text = str(stats.get("round", 0)) + ("  New best" if stats.get("new_best", false) else "")
	kills_label.text = _format_number(int(stats.get("kills", 0)))
	headshots_label.text = _format_number(int(stats.get("headshots", 0)))
	points_label.text = _format_number(int(stats.get("points", 0)))
	_show_loot(stats.get("loot", []), int(stats.get("loot_lost", 0)))
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


func _show_loot(items: Array, lost: int) -> void:
	for card: Node in loot_items.get_children():
		loot_items.remove_child(card)
		card.free()
	loot_empty.visible = items.is_empty()
	loot_title.text = "Loot taken" if lost > 0 else "Loot kept"
	loot_status.text = (
		"Stash full · %d kept, %d item%s lost" % [maxi(items.size() - lost, 0), lost, "" if lost == 1 else "s"]
		if lost > 0
		else "Sent to your stash" if not items.is_empty() else ""
	)
	loot_status.add_theme_color_override("font_color", Color("ff9f1c") if lost > 0 else Color("8fa3a8"))
	var sorted: Array = items.duplicate()
	sorted.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var first: int = ItemRoller.RARITIES.find(StringName(a.get("rar", "common")))
			var second: int = ItemRoller.RARITIES.find(StringName(b.get("rar", "common")))
			return first > second if first != second else int(a.get("ilvl", 1)) > int(b.get("ilvl", 1))
	)
	for index: int in sorted.size():
		_add_loot_card(sorted[index], index == 0)
	_configure_loot_navigation()
	loot_scroll.scroll_vertical = 0


func _add_loot_card(item: Dictionary, best: bool) -> void:
	var rarity_id: StringName = StringName(item.get("rar", "common"))
	var rank: int = ItemRoller.RARITIES.find(rarity_id)
	if rank < 0:
		rarity_id = &"common"
		rank = 0
	var rarity: RarityData = Content.get_item(&"loot", rarity_id) as RarityData
	var card: PanelContainer = PanelContainer.new()
	card.focus_mode = Control.FOCUS_ALL
	var style: StyleBoxFlat = get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
	style.border_color = rarity.colour
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0 if best else 8.0
	style.content_margin_bottom = style.content_margin_top
	card.add_theme_stylebox_override("panel", style)
	card.focus_entered.connect(func() -> void: style.set_border_width_all(3))
	card.focus_exited.connect(func() -> void: style.set_border_width_all(1))
	var lines: VBoxContainer = VBoxContainer.new()
	card.add_child(lines)
	var title: Label = Label.new()
	title.name = "ItemName"
	var base: StringName = StringName(item.get("base", ""))
	title.text = Content.weapon(base).display_name if Content.has(&"weapons", base) else String(base).capitalize()
	title.add_theme_color_override("font_color", rarity.colour)
	title.add_theme_font_size_override("font_size", 26 if best else 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(title)
	var detail: Label = Label.new()
	detail.name = "Rarity"
	detail.text = "%s %s · iLvl %d" % ["●".repeat(rank + 1), String(rarity_id).capitalize(), int(item.get("ilvl", 1))]
	detail.add_theme_color_override("font_color", rarity.colour)
	detail.add_theme_font_size_override("font_size", 18)
	lines.add_child(detail)
	loot_items.add_child(card)


func _configure_loot_navigation() -> void:
	main_menu_button.focus_next = main_menu_button.get_path_to(restart_button)
	main_menu_button.focus_previous = main_menu_button.focus_next
	restart_button.focus_previous = restart_button.get_path_to(main_menu_button)
	restart_button.focus_next = restart_button.focus_previous
	main_menu_button.focus_neighbor_left = NodePath()
	restart_button.focus_neighbor_left = NodePath()
	if loot_items.get_child_count() == 0:
		return
	var first: Control = loot_items.get_child(0) as Control
	var last: Control = loot_items.get_child(-1) as Control
	main_menu_button.focus_neighbor_left = main_menu_button.get_path_to(first)
	restart_button.focus_neighbor_left = restart_button.get_path_to(first)
	main_menu_button.focus_previous = main_menu_button.get_path_to(last)
	restart_button.focus_next = restart_button.get_path_to(first)
	for index: int in loot_items.get_child_count():
		var card: Control = loot_items.get_child(index) as Control
		var previous: Control = loot_items.get_child(index - 1) as Control if index > 0 else restart_button
		var next: Control = loot_items.get_child(index + 1) as Control if card != last else main_menu_button
		card.focus_previous = card.get_path_to(previous)
		card.focus_next = card.get_path_to(next)
		card.focus_neighbor_top = card.focus_previous
		card.focus_neighbor_bottom = card.focus_next
		card.focus_neighbor_right = card.get_path_to(main_menu_button)


func _animate_panels() -> void:
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true)
	for panel: Control in [$StatsPanel, $LootPanel, $ProgressPanel]:
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

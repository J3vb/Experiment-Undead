## Results reflect supplied stats, replay every level and keep navigation focused.
extends GutTest

const RESULTS: PackedScene = preload("res://systems/ui/results_screen.tscn")
const RULES: XpRules = preload("res://content/progression/xp_rules.tres")

var screen: ResultsScreen


func before_each() -> void:
	screen = RESULTS.instantiate() as ResultsScreen
	add_child_autofree(screen)


func test_stats_exfil_and_default_focus() -> void:
	screen.show_results(
		{"round": 17, "kills": 412, "headshots": 168, "points": 61240, "xp": 14930, "exfil": true}, 2468
	)
	assert_eq(screen.round_label.text, "17")
	assert_eq(screen.kills_label.text, "412")
	assert_eq(screen.headshots_label.text, "168")
	assert_eq(screen.points_label.text, "61,240")
	assert_eq(screen.xp_label.text, "XP +14,930")
	assert_eq(screen.map_time.text, "Halcyon Labs · 41:08")
	assert_true(screen.exfil_banner.visible)
	assert_eq(screen.exfil_banner.text, "Exfiltrated")
	assert_true(screen.main_menu_button.has_focus())


func test_bar_replays_partial_levels_and_one_reward_per_crossing() -> void:
	var start: int = RULES.total_xp_for_level(9) + 100
	var finish: int = RULES.total_xp_for_level(11) + 250
	screen.show_results({"start_total_xp": start, "total_xp": finish, "xp": finish - start})
	screen._xp_tween.pause()
	assert_eq(screen.level_label.text, "LV 9")
	assert_almost_eq(screen.xp_bar.value, 100.0, 0.001)
	assert_eq(screen.level_ups.get_child_count(), 0)
	assert_false(screen.exfil_banner.visible)
	var fraction: float = float(RULES.total_xp_for_level(10) - start) / (finish - start)
	screen._xp_tween.custom_step(1.5 * fraction + 0.001)
	assert_eq(screen.level_label.text, "LV 10")
	assert_eq(screen.level_ups.get_child_count(), 1)
	screen._xp_tween.custom_step(1.5)
	assert_eq(screen.level_label.text, "LV 11")
	assert_almost_eq(screen.xp_bar.value, 250.0, 0.001)
	assert_almost_eq(screen.xp_bar.max_value, float(RULES.xp_to_next(11)), 0.001)
	assert_eq(screen.level_ups.get_child_count(), 2)
	for index: int in range(2):
		var level: int = 10 + index
		var row: VBoxContainer = screen.level_ups.get_child(index) as VBoxContainer
		var points: int = RULES.skill_points_for_level(level) - RULES.skill_points_for_level(level - 1)
		assert_eq((row.get_child(0) as Label).text, "Level up! %d → %d" % [level - 1, level])
		assert_eq((row.get_child(1) as Label).text, "+%d skill point%s" % [points, "" if points == 1 else "s"])


func test_no_level_gain_and_reopening_clear_old_rewards() -> void:
	screen.show_results({"start_total_xp": 450, "total_xp": 550})
	screen._xp_tween.pause()
	screen._xp_tween.custom_step(1.6)
	assert_eq(screen.level_ups.get_child_count(), 1)
	screen.show_results({"start_total_xp": 100, "total_xp": 200})
	screen._xp_tween.pause()
	screen._xp_tween.custom_step(1.6)
	assert_eq(screen.level_ups.get_child_count(), 0)
	assert_eq(screen.level_label.text, "LV 1")
	assert_almost_eq(screen.xp_bar.value, 200.0, 0.001)


func test_max_level_is_full_and_only_grants_last_level_once() -> void:
	var cap: int = RULES.total_xp_for_level(RULES.max_level)
	screen.show_results({"start_total_xp": cap - 1, "total_xp": cap + 999})
	screen._xp_tween.pause()
	screen._xp_tween.custom_step(1.6)
	assert_eq(screen.level_label.text, "LV 50")
	assert_almost_eq(screen.xp_bar.value / screen.xp_bar.max_value, 1.0, 0.001)
	assert_eq(screen.level_ups.get_child_count(), 1)
	assert_eq((screen.level_ups.get_child(0).get_child(1) as Label).text, "+2 skill points")


func test_buttons_and_shortcuts_emit_navigation_requests() -> void:
	watch_signals(screen)
	screen.show_results({})
	screen.main_menu_button.pressed.emit()
	screen.restart_button.pressed.emit()
	assert_signal_emitted(screen, "main_menu_requested")
	assert_signal_emitted(screen, "restart_requested")
	var event: InputEventAction = InputEventAction.new()
	event.pressed = true
	event.action = &"reload"
	screen._unhandled_input(event)
	assert_signal_emit_count(screen, "restart_requested", 2)
	event.action = &"ui_cancel"
	screen._unhandled_input(event)
	assert_signal_emit_count(screen, "main_menu_requested", 2)
	screen.hide()
	screen._unhandled_input(event)
	assert_signal_emit_count(screen, "main_menu_requested", 2)


func test_panels_fade_and_slide_twelve_pixels() -> void:
	screen.show_results({})
	screen._panel_tween.pause()
	var panel: Control = screen.get_node("StatsPanel") as Control
	assert_almost_eq(panel.modulate.a, 0.0, 0.001)
	assert_almost_eq(panel.position.y, screen.size.y * 0.25 + 12.0, 0.001)
	screen._panel_tween.custom_step(0.13)
	assert_almost_eq(panel.modulate.a, 1.0, 0.001)
	assert_almost_eq(panel.position.y, screen.size.y * 0.25, 0.001)

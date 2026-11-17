## Text size scales the root window's UI; reduce motion keeps the settings fade in place.
extends GutTest

const SCREEN: PackedScene = preload("res://systems/ui/settings_screen.tscn")
const PATH: String = "user://test_text_scale.cfg"

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


func test_text_size_sets_the_root_scale_factor() -> void:
	Settings.set_value(&"accessibility", &"text_scale", 1.5)
	assert_eq(get_tree().root.content_scale_factor, 1.5)
	Settings.set_value(&"accessibility", &"text_scale", 3.0)
	assert_eq(get_tree().root.content_scale_factor, 1.5, "clamped to 150%")
	Settings.set_value(&"accessibility", &"text_scale", 0.1)
	assert_almost_eq(get_tree().root.content_scale_factor, 0.8, 0.0001)
	Settings.reset_to_defaults()
	assert_eq(get_tree().root.content_scale_factor, 1.0)


func test_reduce_motion_fades_without_sliding() -> void:
	Settings.set_value(&"accessibility", &"reduce_motion", true)
	var screen: SettingsScreen = SCREEN.instantiate() as SettingsScreen
	add_child_autofree(screen)
	assert_eq(screen.position.x, 0.0, "no slide")
	assert_eq(screen.modulate.a, 0.0, "still fades")
	await wait_process_frames(3)
	assert_eq(screen.position.x, 0.0)


func test_normal_motion_slides_in() -> void:
	var screen: SettingsScreen = SCREEN.instantiate() as SettingsScreen
	add_child_autofree(screen)
	assert_eq(screen.position.x, 12.0)


func test_accessibility_page_has_its_rows() -> void:
	var screen: SettingsScreen = SCREEN.instantiate() as SettingsScreen
	add_child_autofree(screen)
	var page: SettingsPage = screen.pages[4]
	assert_eq(page.page, &"accessibility")
	for key: StringName in [&"text_scale", &"toggle_ads", &"toggle_sprint", &"toggle_crouch", &"reduce_motion"]:
		assert_not_null(page.control_for(key), "%s row" % key)


func test_reduce_motion_keeps_results_panels_in_place() -> void:
	Settings.set_value(&"accessibility", &"reduce_motion", true)
	var results: Control = preload("res://systems/ui/results_screen.tscn").instantiate() as Control
	add_child_autofree(results)
	results._animate_panels()
	var panel: Control = results.get_node("StatsPanel") as Control
	assert_almost_eq(panel.position.y, results.size.y * 0.25, 0.01)

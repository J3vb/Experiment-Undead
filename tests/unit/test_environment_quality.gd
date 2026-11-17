## Checks the level look copy: effects follow graphics settings and the shared look file never changes.
extends GutTest

const LOOK: Environment = preload("res://levels/looks/halcyon_interior.tres")
const PATH: String = "user://test_environment_quality.cfg"

var _old_path: String
var _old_values: Dictionary
var _quality: EnvironmentQuality


func before_each() -> void:
	_old_path = Settings.config_path
	_old_values = Settings._values.duplicate(true)
	Settings.config_path = PATH
	Settings.reset_to_defaults()
	_quality = EnvironmentQuality.new()
	_quality.environment = LOOK
	add_child_autofree(_quality)


func after_each() -> void:
	Settings._values = _old_values
	Settings._apply_all()
	Settings.config_path = _old_path
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_defaults_keep_the_look() -> void:
	assert_ne(_quality.environment, LOOK, "works on a copy")
	for property: String in ["ssao_enabled", "ssr_enabled", "glow_enabled", "volumetric_fog_enabled", "ssil_enabled"]:
		assert_eq(_quality.environment.get(property), LOOK.get(property), property)
	assert_almost_eq(_quality.environment.adjustment_brightness, LOOK.adjustment_brightness, 0.001)


func test_low_preset_turns_effects_off_live_without_touching_the_look() -> void:
	Settings.set_value(&"graphics", &"preset", Graphics.Preset.LOW)
	assert_false(_quality.environment.ssao_enabled)
	assert_false(_quality.environment.ssr_enabled)
	assert_false(_quality.environment.volumetric_fog_enabled)
	assert_true(_quality.environment.glow_enabled, "Low keeps glow")
	assert_true(LOOK.ssao_enabled and LOOK.ssr_enabled and LOOK.volumetric_fog_enabled, "shared look unchanged")
	Settings.set_value(&"graphics", &"preset", Graphics.Preset.ULTRA)
	assert_true(_quality.environment.ssao_enabled)
	assert_true(_quality.environment.ssil_enabled, "Ultra adds indirect light")
	assert_false(LOOK.ssil_enabled)


func test_toggles_and_brightness() -> void:
	Settings.set_value(&"graphics", &"glow", false)
	assert_false(_quality.environment.glow_enabled)
	Settings.set_value(&"graphics", &"brightness", 1.2)
	assert_almost_eq(_quality.environment.adjustment_brightness, LOOK.adjustment_brightness * 1.2, 0.001)
	assert_true(_quality.environment.adjustment_enabled)
	assert_almost_eq(LOOK.adjustment_brightness, 1.0, 0.001)

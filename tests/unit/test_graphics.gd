## Checks graphics presets, AA and scaling on a test viewport, window sizes and headless safety.
extends GutTest

var _viewport: SubViewport
var _values: Dictionary


func before_each() -> void:
	_viewport = SubViewport.new()
	add_child_autofree(_viewport)
	_values = Graphics.DEFAULTS.duplicate()


func test_high_preset_is_the_default_look() -> void:
	for key: StringName in Graphics.PRESETS[Graphics.Preset.HIGH]:
		assert_eq(Graphics.DEFAULTS[key], Graphics.PRESETS[Graphics.Preset.HIGH][key], "%s matches High" % key)
	assert_eq(Graphics.DEFAULTS[&"preset"], Graphics.Preset.HIGH)


func test_default_aa_matches_project_settings() -> void:
	Graphics.apply(&"aa", _values, _viewport)
	assert_eq(_viewport.msaa_3d, ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d"))
	assert_eq(_viewport.screen_space_aa, ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa"))
	assert_false(_viewport.use_taa)


func test_every_preset_sets_the_same_keys() -> void:
	var keys: Array = Graphics.PRESETS[0].keys()
	for preset: Dictionary in Graphics.PRESETS:
		assert_eq(preset.keys(), keys)
		for key: StringName in preset:
			assert_eq(Graphics.normalize(key, preset[key]), preset[key], "%s is in range" % key)


func test_preset_links() -> void:
	assert_eq(
		Graphics.linked_changes(&"preset", Graphics.Preset.ULTRA, _values), Graphics.PRESETS[Graphics.Preset.ULTRA]
	)
	assert_eq(Graphics.linked_changes(&"preset", Graphics.Preset.CUSTOM, _values), {})
	assert_eq(Graphics.linked_changes(&"ssao", 2, _values), {}, "same as the preset: stays High")
	assert_eq(Graphics.linked_changes(&"ssao", 0, _values), {&"preset": Graphics.Preset.CUSTOM})
	assert_eq(Graphics.linked_changes(&"render_scale", 0.7, _values), {}, "not a preset key")
	_values[&"preset"] = Graphics.Preset.CUSTOM
	assert_eq(Graphics.linked_changes(&"ssao", 0, _values), {})


func test_aa_choices_and_fsr2_taa() -> void:
	var cases: Array[Array] = [
		[Graphics.Aa.OFF, Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED, false],
		[Graphics.Aa.FXAA, Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_FXAA, false],
		[Graphics.Aa.MSAA_2X, Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_FXAA, false],
		[Graphics.Aa.TAA, Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED, true],
	]
	for entry: Array in cases:
		_values[&"aa"] = entry[0]
		Graphics.apply(&"aa", _values, _viewport)
		assert_eq(_viewport.msaa_3d, entry[1])
		assert_eq(_viewport.screen_space_aa, entry[2])
		assert_eq(_viewport.use_taa, entry[3])
	_values[&"aa"] = Graphics.Aa.MSAA_4X
	_values[&"upscaler"] = Graphics.Upscaler.FSR2
	_values[&"render_scale"] = 0.67
	Graphics.apply(&"upscaler", _values, _viewport)
	assert_eq(Graphics.effective_aa(_values), Graphics.Aa.TAA, "FSR 2 shows as TAA")
	assert_eq(_viewport.msaa_3d, Viewport.MSAA_DISABLED)
	assert_eq(_viewport.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR2)
	assert_almost_eq(_viewport.scaling_3d_scale, 0.67, 0.001)


func test_shadows_and_texture_filtering_reach_the_viewport() -> void:
	_values[&"shadows"] = 1
	Graphics.apply(&"shadows", _values, _viewport)
	assert_eq(_viewport.positional_shadow_atlas_size, 2048)
	_values[&"anisotropic"] = 4
	Graphics.apply(&"anisotropic", _values, _viewport)
	assert_eq(_viewport.anisotropic_filtering_level, Viewport.ANISOTROPY_16X)


func test_window_size_never_bigger_than_the_screen() -> void:
	assert_eq(Graphics.window_size_for(4, Vector2i(1920, 1040)), Vector2i(1920, 1040))
	assert_eq(Graphics.window_size_for(0, Vector2i(1920, 1040)), Vector2i(1280, 720))


func test_window_keys_do_nothing_on_headless() -> void:
	if DisplayServer.get_name() != "headless":
		return
	var fps: int = Engine.max_fps
	_values[&"max_fps"] = 33
	for key: StringName in [&"max_fps", &"vsync", &"display_mode", &"window_size", &"ssr", &"glow"]:
		Graphics.apply(key, _values, _viewport)
	assert_eq(Engine.max_fps, fps)


func test_default_window_choices_keep_the_launch_window() -> void:
	assert_true(Graphics.uses_launch_window(_values), "command-line and editor window sizes are not overridden")
	_values[&"window_size"] = 3
	assert_false(Graphics.uses_launch_window(_values))
	_values[&"window_size"] = Graphics.DEFAULTS[&"window_size"]
	_values[&"display_mode"] = 1
	assert_false(Graphics.uses_launch_window(_values))

## Graphics options: defaults, quality presets, and how each one is applied to the window and renderer.
class_name Graphics

enum Preset { LOW, MEDIUM, HIGH, ULTRA, CUSTOM }
enum Aa { OFF, FXAA, MSAA_2X, MSAA_4X, TAA }
enum Upscaler { OFF, FSR1, FSR2 }

## Choices are indices; ssao, ssil and fog are 0 off, then quality 1 to 3.
## High is today's look (project.godot: MSAA 4x + FXAA).
const DEFAULTS: Dictionary = {
	&"display_mode": 0,
	&"window_size": 1,
	&"render_scale": 1.0,
	&"upscaler": Upscaler.OFF,
	&"preset": Preset.HIGH,
	&"shadows": 2,
	&"aa": Aa.MSAA_4X,
	&"ssao": 2,
	&"ssil": 0,
	&"ssr": true,
	&"glow": true,
	&"fog": 2,
	&"lightmap_bicubic": true,
	&"anisotropic": 2,
	&"brightness": 1.0,
	&"vsync": false,
	&"max_fps": 0,
	&"show_fps": false,
}
const PRESETS: Array[Dictionary] = [
	{&"shadows": 0, &"aa": Aa.FXAA, &"ssao": 0, &"ssil": 0, &"ssr": false, &"fog": 0, &"anisotropic": 1},
	{&"shadows": 1, &"aa": Aa.MSAA_2X, &"ssao": 1, &"ssil": 0, &"ssr": true, &"fog": 1, &"anisotropic": 2},
	{&"shadows": 2, &"aa": Aa.MSAA_4X, &"ssao": 2, &"ssil": 0, &"ssr": true, &"fog": 2, &"anisotropic": 2},
	{&"shadows": 3, &"aa": Aa.MSAA_4X, &"ssao": 3, &"ssil": 2, &"ssr": true, &"fog": 3, &"anisotropic": 4},
]
const DISPLAY_MODES: Array[int] = [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
]
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)
]
## Shadow levels: directional atlas size, soft filter quality (RenderingServer.ShadowQuality).
const SHADOWS: Array[Vector2i] = [Vector2i(1024, 0), Vector2i(2048, 1), Vector2i(4096, 2), Vector2i(8192, 3)]
## Volumetric fog froxel grid size and depth per level; level 0 turns fog off.
const FOG_SIZES: Array[int] = [64, 48, 64, 128]
const CHOICE_COUNTS: Dictionary = {
	&"display_mode": 3,
	&"window_size": 5,
	&"upscaler": 3,
	&"preset": 5,
	&"shadows": 4,
	&"aa": 5,
	&"ssao": 4,
	&"ssil": 4,
	&"fog": 4,
	&"anisotropic": 5,
}


## Clamps a loaded or picked value into its valid range.
static func normalize(key: StringName, value: Variant) -> Variant:
	if value is bool:
		return value
	if CHOICE_COUNTS.has(key):
		return clampi(int(value), 0, CHOICE_COUNTS[key] - 1)
	if key == &"render_scale":
		return clampf(float(value), 0.5, 1.0)
	if key == &"brightness":
		return clampf(float(value), 0.5, 1.5)
	return maxi(int(value), 0)


## Other keys that must change with this one: a preset writes its values, a hand change makes it Custom.
static func linked_changes(key: StringName, value: Variant, values: Dictionary) -> Dictionary:
	var preset: int = values[&"preset"]
	if key == &"preset":
		return PRESETS[value] if value != Preset.CUSTOM else {}
	if preset != Preset.CUSTOM and PRESETS[preset].has(key) and PRESETS[preset][key] != value:
		return {&"preset": Preset.CUSTOM}
	return {}


## FSR 2 brings its own temporal anti-aliasing, so the AA choice shows TAA while it is on.
static func effective_aa(values: Dictionary) -> int:
	return Aa.TAA if values[&"upscaler"] == Upscaler.FSR2 else values[&"aa"]


## Applies one changed key. Window calls are skipped on a headless server; viewport and renderer calls are safe.
static func apply(key: StringName, values: Dictionary, viewport: Viewport) -> void:
	match key:
		&"aa", &"upscaler", &"render_scale":
			_apply_aa_and_scale(values, viewport)
		&"shadows":
			var level: Vector2i = SHADOWS[values[key]]
			RenderingServer.directional_shadow_atlas_set_size(level.x, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(level.y)
			RenderingServer.positional_soft_shadow_filter_set_quality(level.y)
			viewport.positional_shadow_atlas_size = level.x
		&"ssao":
			RenderingServer.environment_set_ssao_quality(values[key], true, 0.5, 2, 50.0, 300.0)
		&"ssil":
			RenderingServer.environment_set_ssil_quality(values[key], true, 0.5, 4, 50.0, 300.0)
		&"fog":
			RenderingServer.environment_set_volumetric_fog_volume_size(FOG_SIZES[values[key]], FOG_SIZES[values[key]])
		&"lightmap_bicubic":
			RenderingServer.lightmaps_set_bicubic_filter(values[key])
		&"anisotropic":
			viewport.anisotropic_filtering_level = values[key]
		_:
			_apply_window(key, values)


static func _apply_aa_and_scale(values: Dictionary, viewport: Viewport) -> void:
	var aa: int = effective_aa(values)
	var msaa: Dictionary = {Aa.MSAA_2X: Viewport.MSAA_2X, Aa.MSAA_4X: Viewport.MSAA_4X}
	viewport.msaa_3d = msaa.get(aa, Viewport.MSAA_DISABLED)
	var fxaa: bool = aa in [Aa.FXAA, Aa.MSAA_2X, Aa.MSAA_4X]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = aa == Aa.TAA and values[&"upscaler"] != Upscaler.FSR2
	var modes: Array[int] = [
		Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR, Viewport.SCALING_3D_MODE_FSR2
	]
	viewport.scaling_3d_mode = modes[values[&"upscaler"]]
	viewport.scaling_3d_scale = values[&"render_scale"]


static func _apply_window(key: StringName, values: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	match key:
		&"max_fps":
			Engine.max_fps = values[key]
		&"vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if values[key] else DisplayServer.VSYNC_DISABLED
			)
		&"display_mode", &"window_size":
			_apply_display(values)


static func _apply_display(values: Dictionary) -> void:
	if uses_launch_window(values):
		return
	var mode: int = DISPLAY_MODES[values[&"display_mode"]]
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
		if DisplayServer.window_get_mode() != mode:
			Log.warn(&"settings", &"display_mode_failed", {"mode": values[&"display_mode"]})
	if mode != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen: int = DisplayServer.window_get_current_screen()
	var usable: Vector2i = DisplayServer.screen_get_usable_rect(screen).size
	var size: Vector2i = window_size_for(values[&"window_size"], usable)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen) + (usable - size) / 2)


## The window size for a choice, shrunk to fit the screen so the window never goes off it.
static func window_size_for(index: int, usable: Vector2i) -> Vector2i:
	return WINDOW_SIZES[index].min(usable)


## Default choices leave the window as launched, so --resolution, --fullscreen and the editor's run size still work.
static func uses_launch_window(values: Dictionary) -> bool:
	return values[&"display_mode"] == DEFAULTS[&"display_mode"] and values[&"window_size"] == DEFAULTS[&"window_size"]

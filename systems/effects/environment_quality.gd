## Turns a level's look effects on or off from the graphics settings, on its own copy of the shared look.
class_name EnvironmentQuality
extends WorldEnvironment

const KEYS: Array[StringName] = [&"ssao", &"ssil", &"ssr", &"glow", &"fog", &"brightness"]

var look: Environment


func _ready() -> void:
	look = environment
	environment = look.duplicate()
	Settings.changed.connect(_on_setting_changed)
	refresh()


func refresh() -> void:
	var on: Callable = func(key: StringName) -> bool: return bool(Settings.get_value(&"graphics", key))
	environment.ssao_enabled = look.ssao_enabled and on.call(&"ssao")
	environment.ssil_enabled = on.call(&"ssil")
	environment.ssr_enabled = look.ssr_enabled and on.call(&"ssr")
	environment.glow_enabled = look.glow_enabled and on.call(&"glow")
	environment.volumetric_fog_enabled = look.volumetric_fog_enabled and on.call(&"fog")
	var brightness: float = float(Settings.get_value(&"graphics", &"brightness"))
	environment.adjustment_enabled = look.adjustment_enabled or not is_equal_approx(brightness, 1.0)
	environment.adjustment_brightness = look.adjustment_brightness * brightness


func _on_setting_changed(section: StringName, key: StringName, _value: Variant) -> void:
	if section == &"graphics" and key in KEYS:
		refresh()

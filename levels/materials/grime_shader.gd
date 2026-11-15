## Binds the shared procedural textures once for all grime surface materials.
@tool
class_name GrimeShader
extends Shader

const SOURCE: Shader = preload("res://levels/materials/grime.gdshader")


func _init() -> void:
	_update_code()
	SOURCE.changed.connect(_update_code)


func _update_code() -> void:
	code = SOURCE.get_code()
	set_default_texture_parameter(&"noise", preload("res://levels/materials/grime_noise.tres"))
	set_default_texture_parameter(&"detail_normal", preload("res://levels/materials/grime_normal.tres"))


func _validate_property(property: Dictionary) -> void:
	if property["name"] == "code":
		property["usage"] = (int(property["usage"]) & ~PROPERTY_USAGE_STORAGE) | PROPERTY_USAGE_READ_ONLY

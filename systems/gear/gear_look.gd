## Applies dyes and rarity to geometry instances without changing shared materials.
class_name GearLook
extends RefCounted


static func apply(root: Node, look: RarityLook, dye_main: Color, dye_accent: Color) -> void:
	var nodes: Array[Node] = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		nodes.push_front(root)
	for node: Node in nodes:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.set_instance_shader_parameter(&"dye_main", dye_main)
		geometry.set_instance_shader_parameter(&"dye_accent", dye_accent)
		geometry.set_instance_shader_parameter(&"trim_color", look.trim_color)
		geometry.set_instance_shader_parameter(&"glow_color", look.trim_color)
		geometry.set_instance_shader_parameter(&"glow_strength", look.glow_strength)
		geometry.set_instance_shader_parameter(&"pulse_seconds", look.pulse_seconds)
		geometry.set_instance_shader_parameter(&"flicker", look.flicker)

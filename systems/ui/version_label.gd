## Small corner text with the build version, plus a note when the last run crashed.
class_name VersionLabel
extends Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override("font_size", 12)
	modulate = Color(1, 1, 1, 0.45)
	text = Build.stage_version()
	if Build.crashed_last_run:
		text = "Last session crashed. Logs: %s\n%s" % [Build.logs_dir(), text]

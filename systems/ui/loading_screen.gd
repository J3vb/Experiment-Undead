## Shown by the UI router while a root place loads: place name, one tip and the load progress.
class_name LoadingScreen
extends ColorRect

const MENU_THEME: Theme = preload("res://systems/ui/menu_theme.tres")

@onready var title_label: Label = %Title
@onready var tip_label: Label = %Tip
@onready var progress_bar: ProgressBar = %Progress


func _ready() -> void:
	theme = preload("res://systems/ui/theme.tres").duplicate() as Theme
	theme.merge_with(MENU_THEME)


func setup(title: String, tips: Array[String]) -> void:
	title_label.text = title
	tip_label.text = tips[randi() % tips.size()] if not tips.is_empty() else ""  # cosmetic


func set_progress(value: float) -> void:
	progress_bar.value = clampf(value, 0.0, 1.0)

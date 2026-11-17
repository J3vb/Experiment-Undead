## Pause menu the match pushes on Esc. Resume and Esc close it; Settings opens above it through the router.
class_name PauseScreen
extends ColorRect

signal closed
signal main_menu_requested
signal quit_requested

const MENU_THEME: Theme = preload("res://systems/ui/menu_theme.tres")

@onready var resume_button: Button = $Menu/Resume
@onready var settings_button: Button = $Menu/Settings
@onready var main_menu_button: Button = $Menu/MainMenu
@onready var quit_button: Button = $Menu/QuitGame


func _ready() -> void:
	theme = preload("res://systems/ui/theme.tres").duplicate() as Theme
	theme.merge_with(MENU_THEME)
	theme.default_font_size = 24
	resume_button.pressed.connect(closed.emit)
	settings_button.pressed.connect(func() -> void: UI.push(&"settings"))
	main_menu_button.pressed.connect(main_menu_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	resume_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()

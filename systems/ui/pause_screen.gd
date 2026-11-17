## Pause menu the match pushes on Esc. Resume and Esc close it; Settings opens above it through the router.
## Alone it freezes the game while open; with friends the match goes on and a banner says so.
## A friend joining while it is open unfreezes it, and it stays unfrozen until closed.
class_name PauseScreen
extends ColorRect

signal closed
signal main_menu_requested
signal quit_requested

const MENU_THEME: Theme = preload("res://systems/ui/menu_theme.tres")

var _froze: bool = false

@onready var resume_button: Button = $Menu/Resume
@onready var settings_button: Button = $Menu/Settings
@onready var main_menu_button: Button = $Menu/MainMenu
@onready var quit_button: Button = $Menu/QuitGame
@onready var banner: Label = $Menu/Banner
@onready var world_line: Label = $Menu/World


func _ready() -> void:
	theme = preload("res://systems/ui/theme.tres").duplicate() as Theme
	theme.merge_with(MENU_THEME)
	theme.default_font_size = 24
	resume_button.pressed.connect(closed.emit)
	settings_button.pressed.connect(func() -> void: UI.push(&"settings"))
	main_menu_button.pressed.connect(main_menu_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	resume_button.grab_focus()
	banner.visible = Net.is_coop()
	if not banner.visible:
		_froze = true
		get_tree().paused = true
	Net.coop_changed.connect(_on_coop_changed)
	world_line.text = world_text(Net.world.state)
	world_line.visible = not world_line.text.is_empty()


## Only the world's owner sees whether friends can join, and on which port.
static func world_text(state: Dictionary) -> String:
	match state.get("status", &""):
		&"open":
			return "Friends can join on port %d" % state.port
		&"offline_busy":
			return "Port %d is in use, friends can't join" % state.port
	return ""


func _exit_tree() -> void:
	if _froze:
		get_tree().paused = false


func _on_coop_changed(on: bool) -> void:
	if not on:
		return
	banner.visible = true
	if _froze:
		_froze = false
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()

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
@onready var copy_button: Button = $Menu/CopyAddress


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
	copy_button.pressed.connect(func() -> void: DisplayServer.clipboard_set(world_address(Net.world.state)))
	Net.world.changed.connect(_show_world)
	_show_world()


## Only the world's owner sees whether friends can join, and the address they add.
static func world_text(state: Dictionary) -> String:
	var port: int = state.get("port", 0)
	if state.get("status") == &"offline_busy":
		return "Port %d is in use, friends can't join" % port
	if state.get("status") != &"open":
		return ""
	var at: String = "%s:%d" % [state.get("address", ""), port]
	var by_hand: String = "open UDP %d and %d on your router for friends over the internet" % [port, port + 1000]
	match state.get("router"):
		&"opened":
			return "Friends add you at %s" % at
		&"pending":
			return "Friends can join on port %d. Checking your router..." % port
		&"cgnat":
			var shared: String = "Your internet provider shares your address, so internet friends can't reach you"
			return "Friends on your network add you at %s. %s." % [at, shared]
		&"no_router":
			return "Friends on your network add you at %s. Your router did not answer: %s." % [at, by_hand]
		&"failed":
			return "Friends on your network add you at %s. Your router refused: %s." % [at, by_hand]
		&"off":
			return "Friends on your network add you at %s. To let others in, %s." % [at, by_hand]
	return "Friends can join on port %d" % port


## address:port for the Copy button, or "" when there is nothing to copy.
static func world_address(state: Dictionary) -> String:
	if state.get("status") != &"open" or str(state.get("address", "")).is_empty():
		return ""
	return "%s:%d" % [state.address, state.port]


func _show_world() -> void:
	world_line.text = world_text(Net.world.state)
	world_line.visible = not world_line.text.is_empty()
	copy_button.visible = not world_address(Net.world.state).is_empty()


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

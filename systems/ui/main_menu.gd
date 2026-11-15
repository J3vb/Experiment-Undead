## Solo front end with shared settings and bundled third-party credits.
class_name MainMenu
extends Control

const PLAY_SCENE: String = "res://systems/game/game_session.tscn"
const CREDITS: String = """Atkinson Hyperlegible Next and Mono, `assets/fonts/`
Braille Institute of America, Applied Design Works
https://github.com/googlefonts/atkinson-hyperlegible-next · SIL OFL 1.1

GUT (Godot Unit Test) 9.7.1, `addons/gut/`
Butch Wesley and contributors
https://github.com/bitwes/Gut · MIT"""

var _panel_tween: Tween
var _drift_time: float = 0.0

@onready var menu: VBoxContainer = $Screens/Root/Menu
@onready var play_button: Button = $Screens/Root/Menu/Play
@onready var settings_button: Button = $Screens/Root/Menu/Settings
@onready var credits_button: Button = $Screens/Root/Menu/Credits
@onready var settings_screen: SettingsScreen = $Screens/Root/SettingsScreen
@onready var credits_panel: PanelContainer = $Screens/Root/CreditsPanel
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	play_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(PLAY_SCENE))
	settings_button.pressed.connect(_open_settings)
	credits_button.pressed.connect(_open_credits)
	$Screens/Root/Menu/Quit.pressed.connect(func() -> void: get_tree().quit())
	settings_screen.closed.connect(_close_settings)
	$Screens/Root/CreditsPanel/Box/Back.pressed.connect(_close_credits)
	$Screens/Root/CreditsPanel/Box/Text.text = CREDITS
	$Screens/Root.add_child(VersionLabel.new())
	play_button.grab_focus()
	_launch_from_command_line.call_deferred(OS.get_cmdline_user_args())


func _launch_from_command_line(args: PackedStringArray) -> void:
	var launch: Dictionary = parse_launch(args)
	if launch.has("join"):
		Net.pending_join = launch["join"]
	elif launch.has("host"):
		var err: Error = Net.host(launch["host"])
		if err != OK:
			Log.error(&"net", &"host_failed", {"port": launch["host"], "error": error_string(err)})
			return
	else:
		return
	get_tree().change_scene_to_file(PLAY_SCENE)


## "--join=address:port" -> {"join": "address:port"}; "--host" or "--host=port" -> {"host": port}.
static func parse_launch(args: PackedStringArray) -> Dictionary:
	for arg: String in args:
		if arg.begins_with("--join="):
			return {"join": arg.substr(7)}
		if arg == "--host":
			return {"host": Net.DEFAULT_PORT}
		if arg.begins_with("--host=") and arg.substr(7).is_valid_int():
			return {"host": arg.substr(7).to_int()}
	return {}


func _process(delta: float) -> void:
	_drift_time += delta
	camera.position.x = 24.0 + sin(_drift_time * 0.2) * 0.15
	camera.rotation.y = sin(_drift_time * 0.15) * 0.015


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if settings_screen.visible:
		settings_screen._close()
	elif credits_panel.visible:
		_close_credits()
	else:
		return
	get_viewport().set_input_as_handled()


func _open_settings() -> void:
	menu.hide()
	if _panel_tween:
		_panel_tween.kill()
	settings_screen.show()
	settings_screen.modulate.a = 0.0
	settings_screen.position.x = 12.0
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(settings_screen, "modulate:a", 1.0, 0.12)
	_panel_tween.tween_property(settings_screen, "position:x", 0.0, 0.12)
	(settings_screen.get_node("Margin/Box/Tabs") as TabContainer).get_tab_bar().grab_focus()


func _close_settings() -> void:
	settings_screen.hide()
	menu.show()
	settings_button.grab_focus()


func _open_credits() -> void:
	menu.hide()
	if _panel_tween:
		_panel_tween.kill()
	credits_panel.show()
	credits_panel.modulate.a = 0.0
	credits_panel.position.x = 12.0
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(credits_panel, "modulate:a", 1.0, 0.12)
	_panel_tween.tween_property(credits_panel, "position:x", 0.0, 0.12)
	($Screens/Root/CreditsPanel/Box/Back as Button).grab_focus()


func _close_credits() -> void:
	credits_panel.hide()
	menu.show()
	credits_button.grab_focus()

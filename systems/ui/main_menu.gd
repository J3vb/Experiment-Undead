## Front end: Enter world opens your own world, Servers joins someone else's. Shared settings
## and plain-word network errors.
class_name MainMenu
extends Control

const CREDITS: String = """Atkinson Hyperlegible Next and Mono, `assets/fonts/`
Braille Institute of America, Applied Design Works
https://github.com/googlefonts/atkinson-hyperlegible-next · SIL OFL 1.1

GUT (Godot Unit Test) 9.7.1, `addons/gut/`
Butch Wesley and contributors
https://github.com/bitwes/Gut · MIT

Shambler, Shambler guard and Bloater zombies, `assets/models/zombies/{shambler,shambler_guard,bloater}.glb`
Made for this project with Tripo AI (image to 3D, paid plan)
https://www.tripo3d.ai · Owned by this project, commercial use

Glower zombie, `assets/models/zombies/glower.glb`
Made for this project with Tripo AI (image to 3D, paid plan)
https://www.tripo3d.ai · Owned by this project, commercial use

Lantern Post market stalls, `assets/models/town_large/stall_*.glb`
Made for this project with Tripo AI (image to 3D, paid plan)
https://www.tripo3d.ai · Owned by this project, commercial use

MakeHuman base mesh (head only), `tools/assets/player_body/base_head.obj`
Data Collection AB, Joel Palmius, Jonas Hauquier
https://github.com/makehumancommunity/makehuman · CC0 1.0"""

const NEWER_SAVE: String = (
	"This character was saved by a newer version of the game. "
	+ "Update the game to play it. Your save was not changed."
)

static var launch_consumed: bool = false

var _panel_tween: Tween
var _drift_time: float = 0.0
## Character waiting for the newer-save message to close before its screen opens.
var _pending_profile: CharacterProfile

@onready var menu: VBoxContainer = $Screens/Root/Menu
@onready var enter_button: Button = $Screens/Root/Menu/EnterWorld
@onready var servers_button: Button = $Screens/Root/Menu/Servers
@onready var loadout_button: Button = $Screens/Root/Menu/Loadout
@onready var settings_button: Button = $Screens/Root/Menu/Settings
@onready var credits_button: Button = $Screens/Root/Menu/Credits
@onready var credits_panel: PanelContainer = $Screens/Root/CreditsPanel
@onready var camera: Camera3D = $Camera3D
@onready var error_dialog: NetErrorDialog = $NetErrorDialog


func _ready() -> void:
	if _hand_over():
		return
	Net.cancel_place_change()
	_bind_gamepad()
	Net.world.close()
	enter_button.pressed.connect(enter_world)
	servers_button.pressed.connect(_open_servers)
	error_dialog.closed.connect(_close_error)
	loadout_button.pressed.connect(_open_character)
	settings_button.pressed.connect(_open_settings)
	credits_button.pressed.connect(_open_credits)
	$Screens/Root/Menu/Quit.pressed.connect(func() -> void: get_tree().quit())
	$Screens/Root/CreditsPanel/Box/Back.pressed.connect(_close_credits)
	$Screens/Root/CreditsPanel/Box/Text.text = CREDITS
	$Screens/Root.add_child(VersionLabel.new())
	enter_button.grab_focus()
	if not Net.last_error.is_empty():
		_show_error(Net.last_error["reason"], Net.last_error["details"])
		Net.last_error.clear()
	_launch_from_command_line.call_deferred(OS.get_cmdline_user_args())


## "--server" runs this build as a dedicated server (the launcher's Host a server). Players
## start the game from the separate launcher (F-82), so there is no launcher screen here.
func _hand_over() -> bool:
	if parse_launch(OS.get_cmdline_user_args()).has("server"):
		UI.replace.call_deferred(&"dedicated_server")
		return true
	return false


## Command-line launches run once per process, so returning to the menu
## after a failed join or a hosted match does not start them again.
func _launch_from_command_line(args: PackedStringArray) -> void:
	if launch_consumed:
		return
	launch_consumed = true
	var launch: Dictionary = parse_launch(args)
	if launch.has("join"):
		_start_join(launch["join"])
	elif launch.has("host"):
		_start_host(launch["host"])


## "--join=address:port" -> {"join": "address:port"}; "--host" or "--host=port" -> {"host": port};
## "--server" -> {"server": true}.
static func parse_launch(args: PackedStringArray) -> Dictionary:
	for arg: String in args:
		if arg == "--server":
			return {"server": true}
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
	if not UI.top().is_empty() or not event.is_action_pressed(&"ui_cancel"):
		return
	if error_dialog.visible:
		return
	if credits_panel.visible:
		_close_credits()
		get_viewport().set_input_as_handled()


## Your own Lantern Post: open to friends on the saved port, or offline when it cannot be
## (the pause screen says why). Nothing here joins anyone else's game.
func enter_world() -> void:
	Net.world.open(int(Settings.get_value(&"network", &"last_port")))
	Net.place = &"hub"
	UI.replace(&"hub")


## The server browser: the only way into someone else's game.
func _open_servers() -> void:
	if UI.top().is_empty():
		UI.push(&"server_browser")


func _start_host(port: int) -> void:
	if port < 1 or port > 65535:
		_show_error(&"invalid_port")
		return
	var err: Error = Net.host(port)
	if err != OK:
		_show_error(&"port_in_use", {"port": port})
		Net.last_error.clear()
		return
	Net.place = &"hub"
	UI.replace(&"hub")


func _start_join(address: String) -> void:
	var target: String = ServerAddress.normalized(address)
	if target.is_empty():
		_show_error(&"bad_address")
		return
	Settings.set_value(&"network", &"last_address", address.strip_edges())
	Net.pending_join = target
	error_dialog.reparent(get_tree().root)
	error_dialog.show_connecting(target)
	Net.place = &"hub"
	UI.replace(&"hub")


func _show_error(reason: StringName, details: Dictionary = {}) -> void:
	$Screens/Root.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	$Screens/Root.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	error_dialog.show_error(reason, details)


func _close_error() -> void:
	$Screens/Root.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	$Screens/Root.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if _pending_profile:
		var profile: CharacterProfile = _pending_profile
		_pending_profile = null
		(UI.push(&"character") as CharacterScreen).open(profile)
	else:
		enter_button.grab_focus()


func _open_settings() -> void:
	if UI.top().is_empty():
		UI.push(&"settings")


func _open_credits() -> void:
	menu.hide()
	if _panel_tween:
		_panel_tween.kill()
	credits_panel.show()
	credits_panel.modulate.a = 0.0
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(credits_panel, "modulate:a", 1.0, 0.12)
	if not Settings.get_value(&"accessibility", &"reduce_motion"):
		credits_panel.position.x = 12.0
		_panel_tween.tween_property(credits_panel, "position:x", 0.0, 0.12)
	($Screens/Root/CreditsPanel/Box/Back as Button).grab_focus()


func _close_credits() -> void:
	credits_panel.hide()
	menu.show()
	credits_button.grab_focus()


func _open_character() -> void:
	if not UI.top().is_empty():
		return
	var profile: CharacterProfile = CharacterProfile.load_or_create(&"solo")
	if not profile.saved_by_newer_version:
		(UI.push(&"character") as CharacterScreen).open(profile)
		return
	_pending_profile = profile
	_show_error(&"newer_save")
	error_dialog.message_label.text = NEWER_SAVE


func _bind_gamepad() -> void:
	var pad_actions: Dictionary = {
		&"ui_accept": JOY_BUTTON_A,
		&"ui_cancel": JOY_BUTTON_B,
		&"ui_up": JOY_BUTTON_DPAD_UP,
		&"ui_down": JOY_BUTTON_DPAD_DOWN,
		&"ui_left": JOY_BUTTON_DPAD_LEFT,
		&"ui_right": JOY_BUTTON_DPAD_RIGHT
	}
	for action: StringName in pad_actions:
		var binding: InputEventJoypadButton = InputEventJoypadButton.new()
		binding.button_index = pad_actions[action]
		if not InputMap.action_has_event(action, binding):
			InputMap.action_add_event(action, binding)

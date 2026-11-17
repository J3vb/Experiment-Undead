## Solo and co-op front end with shared settings and plain-word network errors.
class_name MainMenu
extends Control

const CREDITS: String = """Atkinson Hyperlegible Next and Mono, `assets/fonts/`
Braille Institute of America, Applied Design Works
https://github.com/googlefonts/atkinson-hyperlegible-next · SIL OFL 1.1

GUT (Godot Unit Test) 9.7.1, `addons/gut/`
Butch Wesley and contributors
https://github.com/bitwes/Gut · MIT"""

static var launch_consumed: bool = false

var _panel_tween: Tween
var _drift_time: float = 0.0

@onready var menu: VBoxContainer = $Screens/Root/Menu
@onready var play_button: Button = $Screens/Root/Menu/Play
@onready var host_button: Button = $Screens/Root/Menu/Host
@onready var join_button: Button = $Screens/Root/Menu/Join
@onready var character_button: Button = $Screens/Root/Menu/Character
@onready var settings_button: Button = $Screens/Root/Menu/Settings
@onready var credits_button: Button = $Screens/Root/Menu/Credits
@onready var credits_panel: PanelContainer = $Screens/Root/CreditsPanel
@onready var camera: Camera3D = $Camera3D
@onready var host_panel: PanelContainer = $Screens/Root/HostPanel
@onready var join_panel: PanelContainer = $Screens/Root/JoinPanel
@onready var port_field: LineEdit = $Screens/Root/HostPanel/Box/Port
@onready var address_field: LineEdit = $Screens/Root/JoinPanel/Box/Address
@onready var error_dialog: NetErrorDialog = $NetErrorDialog


func _ready() -> void:
	Net.cancel_place_change()
	_bind_gamepad()
	play_button.pressed.connect(_play_solo)
	host_button.pressed.connect(_open_host)
	join_button.pressed.connect(_open_join)
	$Screens/Root/HostPanel/Box/Start.pressed.connect(_host)
	$Screens/Root/HostPanel/Box/Back.pressed.connect(_close_coop)
	$Screens/Root/JoinPanel/Box/Connect.pressed.connect(_join)
	$Screens/Root/JoinPanel/Box/Back.pressed.connect(_close_coop)
	port_field.text_submitted.connect(func(_text: String) -> void: _host())
	address_field.text_submitted.connect(func(_text: String) -> void: _join())
	error_dialog.closed.connect(_close_error)
	character_button.pressed.connect(_open_character)
	settings_button.pressed.connect(_open_settings)
	credits_button.pressed.connect(_open_credits)
	$Screens/Root/Menu/Quit.pressed.connect(func() -> void: get_tree().quit())
	$Screens/Root/CreditsPanel/Box/Back.pressed.connect(_close_credits)
	$Screens/Root/CreditsPanel/Box/Text.text = CREDITS
	$Screens/Root.add_child(VersionLabel.new())
	play_button.grab_focus()
	if not Net.last_error.is_empty():
		_show_error(Net.last_error["reason"], Net.last_error["details"])
		Net.last_error.clear()
	_launch_from_command_line.call_deferred(OS.get_cmdline_user_args())


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
	if not UI.top().is_empty() or not event.is_action_pressed(&"ui_cancel"):
		return
	if error_dialog.visible:
		return
	if host_panel.visible or join_panel.visible:
		_close_coop()
	elif credits_panel.visible:
		_close_credits()
	else:
		return
	get_viewport().set_input_as_handled()


## Play solo skips the hub and goes straight into the match.
func _play_solo() -> void:
	Net.place = &"match"
	UI.replace(&"match")


func _open_host() -> void:
	menu.hide()
	port_field.text = str(Settings.get_value(&"network", &"last_port"))
	host_panel.show()
	port_field.grab_focus()
	port_field.select_all()


func _open_join() -> void:
	menu.hide()
	address_field.text = str(Settings.get_value(&"network", &"last_address"))
	join_panel.show()
	address_field.grab_focus()
	address_field.select_all()


func _close_coop() -> void:
	var return_focus: Button = host_button if host_panel.visible else join_button
	host_panel.hide()
	join_panel.hide()
	menu.show()
	return_focus.grab_focus()


func _host() -> void:
	var port: int = port_field.text.to_int()
	if not port_field.text.is_valid_int() or port < 1 or port > 65535:
		_show_error(&"invalid_port")
		return
	Settings.set_value(&"network", &"last_port", port)
	_start_host(port)


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


func _join() -> void:
	_start_join(address_field.text)


func _start_join(address: String) -> void:
	var target: String = normalized_address(address)
	if target.is_empty():
		_show_error(&"bad_address")
		return
	Settings.set_value(&"network", &"last_address", address.strip_edges())
	Net.pending_join = target
	error_dialog.reparent(get_tree().root)
	error_dialog.show_connecting(target)
	Net.place = &"hub"
	UI.replace(&"hub")


## Validate before Net.join so malformed input never opens a connection.
static func normalized_address(text: String) -> String:
	var parts: PackedStringArray = _address_parts(text.strip_edges())
	if parts.size() != 2 or not _valid_host(parts[0]) or not parts[1].is_valid_int():
		return ""
	var port: int = parts[1].to_int()
	if port < 1 or port > 65535:
		return ""
	return "%s:%d" % [parts[0], port]


static func _address_parts(address: String) -> PackedStringArray:
	if address.begins_with("["):
		return _bracketed_address_parts(address)
	var colon: int = address.rfind(":")
	if colon < 0:
		return PackedStringArray([address, str(Net.DEFAULT_PORT)])
	var host: String = address.substr(0, colon)
	var port: String = address.substr(colon + 1)
	# Keep legacy IPv6 host:port parsing; brackets disambiguate a literal's last group.
	if address.count(":") == 1 or (host.is_valid_ip_address() and port.is_valid_int()):
		return PackedStringArray([host, port])
	return PackedStringArray([address, str(Net.DEFAULT_PORT)])


static func _bracketed_address_parts(address: String) -> PackedStringArray:
	var close: int = address.find("]")
	if close < 0:
		return PackedStringArray()
	var host: String = address.substr(1, close - 1)
	var suffix: String = address.substr(close + 1)
	if not host.contains(":") or not host.is_valid_ip_address():
		return PackedStringArray()
	if suffix.is_empty():
		return PackedStringArray([host, str(Net.DEFAULT_PORT)])
	if not suffix.begins_with(":"):
		return PackedStringArray()
	return PackedStringArray([host, suffix.substr(1)])


static func _valid_host(host: String) -> bool:
	if host.is_empty() or host.length() > 253:
		return false
	if host.is_valid_ip_address():
		return true
	if host.replace(".", "").is_valid_int():
		return false
	var label_pattern: RegEx = RegEx.create_from_string("^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$")
	for label: String in host.split("."):
		if label_pattern.search(label) == null:
			return false
	return true


func _show_error(reason: StringName, details: Dictionary = {}) -> void:
	$Screens/Root.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	$Screens/Root.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	error_dialog.show_error(reason, details)


func _close_error() -> void:
	$Screens/Root.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	$Screens/Root.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if host_panel.visible:
		port_field.grab_focus()
	elif join_panel.visible:
		address_field.grab_focus()
	else:
		play_button.grab_focus()


func _open_settings() -> void:
	if UI.top().is_empty():
		UI.push(&"settings")


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


func _open_character() -> void:
	if UI.top().is_empty():
		(UI.push(&"character") as CharacterScreen).open(CharacterProfile.load_or_create(&"solo"))


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

## In-match HUD and pause menu; gameplay facts arrive through Events.
class_name Hud
extends CanvasLayer

const BLOOD_RED: Color = Color("c8202a")
const OFF_WHITE: Color = Color("f2ede0")
const SERUM_STYLES: Dictionary = {
	&"ironhide": ["IH", Color("765054")],
	&"quickhands": ["QH", Color("85724c")],
	&"overclock": ["OC", Color("4c727c")],
	&"deadeye": ["DE", Color("75607e")],
	&"mule": ["MU", Color("65764c")],
	&"stride": ["ST", Color("4e7870")],
	&"second_wind": ["SW", Color("776951")],
	&"scavenger": ["SC", Color("596b80")],
}

var _round_tween: Tween
var _prompt_text: String = ""
var _player: Player
var _hurt: float = 0.0
var _health_ratio: float = 1.0
var _center_time: float = 0.0
var _delta_time: float = 0.0
var _delta_sum: int = 0
var _exfil: ExfilHatch
var _fps_label: Label

@onready var crosshair: Crosshair = $Root/Crosshair
@onready var hit_marker: HitMarker = $Root/HitMarker
@onready var vignette: ColorRect = $Root/DamageVignette
@onready var round_label: Label = $Root/RoundInfo/RoundLabel
@onready var points_label: Label = $Root/Loadout/PointsLabel
@onready var points_delta: Label = $Root/Loadout/PointsDelta
@onready var serums: HBoxContainer = $Root/Vitals/Serums
@onready var health_bar: ProgressBar = $Root/Vitals/Health
@onready var ammo_label: Label = $Root/Loadout/Ammo/AmmoLabel
@onready var weapon_label: Label = $Root/Loadout/WeaponLabel
@onready var reserve_label: Label = $Root/Loadout/Ammo/ReserveLabel
@onready var exfil_box: PanelContainer = $Root/ExfilBox
@onready var exfil_title: Label = $Root/ExfilBox/Box/Title
@onready var exfil_bar: ProgressBar = $Root/ExfilBox/Box/Hold
@onready var exfil_time: Label = $Root/ExfilBox/Box/Time
@onready var prompt_box: PanelContainer = $Root/Prompt
@onready var prompt_key: Label = $Root/Prompt/Row/Key
@onready var prompt_price: Label = $Root/Prompt/Row/Price
@onready var hint_label: Label = $Root/HintLabel
@onready var center_label: Label = $Root/CenterLabel
@onready var prompt_label: Label = $Root/Prompt/Row/PromptLabel
@onready var pause_panel: Control = $Root/PausePanel
@onready var settings_screen: SettingsScreen = $Root/PausePanel/SettingsScreen
@onready var pause_menu: Control = $Root/PausePanel/Menu
@onready var resume_button: Button = $Root/PausePanel/Menu/Resume
@onready var settings_button: Button = $Root/PausePanel/Menu/Settings
@onready var game_over_panel: Control = $Root/GameOverPanel
@onready var game_over_stats: Label = $Root/GameOverPanel/Box/Stats
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var round_sound: AudioStreamPlayer = $RoundSound


func _ready() -> void:
	_setup_pause_menu()
	var bold: FontVariation = FontVariation.new()
	bold.base_font = round_label.get_theme_font("font")
	bold.variation_embolden = 1.2
	round_label.add_theme_font_override("font", bold)
	pause_panel.visible = false
	game_over_panel.visible = false
	center_label.modulate.a = 0.0
	points_delta.modulate.a = 0.0
	hint_label.text = ""
	round_label.text = ""
	$Root.add_child(VersionLabel.new())
	Events.player_spawned.connect(_on_player_spawned)
	Events.player_health_changed.connect(_on_health_changed)
	Events.player_damaged.connect(_on_player_damaged)
	Events.points_changed.connect(_on_points_changed)
	Events.ammo_changed.connect(_on_ammo_changed)
	Events.weapon_switched.connect(_on_weapon_switched)
	Events.hit_confirmed.connect(_on_hit_confirmed)
	Events.serum_gained.connect(_on_serum_gained)
	Events.power_up_collected.connect(_on_power_up_collected)
	Events.player_revived.connect(_on_player_revived)
	Events.round_started.connect(_on_round_started)
	Events.round_ended.connect(_on_round_ended)
	Events.intermission_started.connect(_on_intermission)
	Events.exfil_opened.connect(_on_exfil_opened)
	Events.exfil_called.connect(func(hatch: ExfilHatch) -> void: _exfil = hatch)
	Events.game_over.connect(_on_game_over)


func show_paused(paused: bool) -> void:
	pause_panel.visible = paused
	settings_screen.hide()
	pause_menu.show()
	if paused:
		resume_button.grab_focus()


func _process(delta: float) -> void:
	_fps_label.visible = bool(Settings.get_value(&"video", &"show_fps"))
	if _fps_label.visible:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_hurt = maxf(_hurt - delta * 1.5, 0.0)
	var low: float = clampf((0.6 - _health_ratio) / 0.6, 0.0, 1.0)
	(vignette.material as ShaderMaterial).set_shader_parameter("intensity", clampf(maxf(_hurt, low * 0.85), 0.0, 1.0))

	if _center_time > 0.0:
		_center_time -= delta
		center_label.modulate.a = clampf(_center_time, 0.0, 1.0)
	if _delta_time > 0.0:
		_delta_time -= delta
		points_delta.modulate.a = clampf(_delta_time * 2.0, 0.0, 1.0)
		if _delta_time <= 0.0:
			_delta_sum = 0

	_update_exfil()
	_update_prompt(_player.focus.get_prompt(_player) if is_instance_valid(_player) and _player.focus else "")
	if is_instance_valid(_player) and _player.weapons.current:
		var w: Weapon = _player.weapons.current
		crosshair.spread_degrees = w.get_current_spread()
		crosshair.fov_degrees = _player.camera.fov
		crosshair.modulate.a = 0.0 if (w.ads_progress > 0.5 or _player.is_sprinting or not _player.is_alive()) else 1.0


func _on_exfil_opened() -> void:
	_exfil = get_tree().get_first_node_in_group(&"exfil") as ExfilHatch
	_update_exfil()


func _update_exfil() -> void:
	exfil_box.visible = is_instance_valid(_exfil) and (_exfil.is_open or _exfil.is_holding)
	if not exfil_box.visible:
		return
	exfil_title.text = "Exfil open · Containment Wing"
	exfil_bar.value = 1.0 - _exfil.hold_left / ExfilHatch.HOLD_TIME
	var seconds: int = maxi(ceili(_exfil.hold_left), 0)
	exfil_time.text = "Hold %d:%02d" % [seconds / 60, seconds % 60]
	if _exfil.is_holding and not _exfil.has_player_in_zone():
		exfil_time.text += " · Return to hatch"


func _update_prompt(text: String) -> void:
	if text == _prompt_text:
		return
	_prompt_text = text
	prompt_box.visible = not text.is_empty()
	prompt_key.visible = text.contains("[F]")
	prompt_price.text = ""
	var parts: PackedStringArray = text.split("[F]", true, 1)
	if parts.size() == 2 and parts[1].strip_edges().is_valid_int():
		prompt_price.text = parts[1].strip_edges()
		prompt_label.text = parts[0].strip_edges()
	else:
		prompt_label.text = text.replace("[F]", "").strip_edges()


func _format_points(value: int) -> String:
	var digits: String = str(absi(value))
	var index: int = digits.length() - 3
	while index > 0:
		digits = digits.insert(index, ",")
		index -= 3
	return ("-" if value < 0 else "") + digits


func _flash_center(text: String, seconds: float) -> void:
	center_label.text = text
	_center_time = seconds


func _on_player_spawned(player: Player) -> void:
	if _player == null:
		_player = player


func _on_health_changed(player: Player, current: float, maximum: float) -> void:
	if player == _player:
		_health_ratio = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
		health_bar.value = _health_ratio
		health_bar.modulate = BLOOD_RED if _health_ratio < 0.3 else OFF_WHITE


func _on_player_damaged(player: Player, _info: DamageInfo) -> void:
	if player == _player:
		_hurt = 0.8


func _on_points_changed(player: Player, total: int, delta: int) -> void:
	if player != _player:
		return
	points_label.text = _format_points(total)
	if delta > 0:
		_delta_sum += delta
		points_delta.text = "+%d" % _delta_sum
		_delta_time = 1.2


func _on_ammo_changed(player: Player, in_mag: int, reserve: int) -> void:
	if player != _player:
		return
	ammo_label.text = str(in_mag)
	reserve_label.text = "/ %d" % reserve
	var low: bool = _player.weapons.current and in_mag <= _player.weapons.current.data.magazine_size / 4
	ammo_label.modulate = BLOOD_RED if low else OFF_WHITE
	if in_mag == 0 and reserve == 0:
		hint_label.text = "NO AMMO"
	elif low and reserve > 0:
		hint_label.text = "RELOAD [R]"
	else:
		hint_label.text = ""


func _on_weapon_switched(player: Player, weapon: Weapon) -> void:
	if player == _player:
		weapon_label.text = weapon.data.display_name


func _on_serum_gained(player: Player, _serum: SerumData) -> void:
	if player != _player:
		return
	if not SERUM_STYLES.has(_serum.id):
		return
	for badge: Node in serums.get_children():
		if badge.name == String(_serum.id):
			return
	var style: Array = SERUM_STYLES[_serum.id]
	var square: StyleBoxFlat = StyleBoxFlat.new()
	square.bg_color = style[1]
	var label: Label = Label.new()
	label.name = String(_serum.id)
	label.text = style[0]
	label.tooltip_text = _serum.display_name
	label.custom_minimum_size = Vector2(44, 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", square)
	serums.add_child(label)


func _on_hit_confirmed(player: Player, is_kill: bool, is_headshot: bool) -> void:
	if player != _player:
		return
	hit_marker.show_hit(is_kill, is_headshot)
	hit_sound.pitch_scale = 0.8 if is_kill else 1.0
	hit_sound.play()


func _on_power_up_collected(_collector: Player, power_up: PowerUpData) -> void:
	_flash_center(power_up.display_name.to_upper(), 2.0)


func _on_player_revived(player: Player) -> void:
	if player == _player:
		_flash_center("SECOND WIND", 2.0)
		for badge: Node in serums.get_children():
			if not player.has_serum(StringName(badge.name)):
				serums.remove_child(badge)
				badge.queue_free()


func _on_round_started(round_number: int, _count: int) -> void:
	if _round_tween:
		_round_tween.kill()
	round_label.text = str(round_number)
	round_label.modulate = Color.WHITE
	_round_tween = create_tween()
	_round_tween.tween_property(round_label, "modulate", BLOOD_RED, 1.0)
	_flash_center("ROUND %d" % round_number, 3.0)
	round_sound.play()


func _on_round_ended(round_number: int) -> void:
	($RoundEndSound as AudioStreamPlayer).play()
	_flash_center("ROUND %d SURVIVED" % round_number, 3.0)


func _on_intermission(next_round: int, duration: float) -> void:
	if _round_tween:
		_round_tween.kill()
	_round_tween = create_tween().set_loops()
	_round_tween.tween_property(round_label, "modulate:a", 0.3, 0.8)
	_round_tween.tween_property(round_label, "modulate:a", 1.0, 0.8)
	if next_round == 1:
		_flash_center("SURVIVE", duration)


func _on_game_over(stats: Dictionary) -> void:
	game_over_panel.visible = true
	_exfil = null
	exfil_box.hide()
	($Root/GameOverPanel/Box/MainMenu as Button).grab_focus()
	game_over_stats.text = (
		("Exfil successful: +50% XP\n" if stats.get("exfil", false) else "")
		+ (
			"You survived %d round%s\n%d kills    %d points    %d XP\n\nR: restart    Esc: main menu"
			% [
				stats.get("round", 0),
				"" if stats.get("round", 0) == 1 else "s",
				stats.get("kills", 0),
				stats.get("points", 0),
				stats.get("xp", 0)
			]
		)
	)


func _setup_pause_menu() -> void:
	pause_panel.theme = settings_screen.theme
	resume_button.pressed.connect(func() -> void: (get_parent() as GameSession).resume())
	settings_button.pressed.connect(_open_settings)
	$Root/PausePanel/Menu/MainMenu.pressed.connect(_return_to_menu)
	$Root/PausePanel/Menu/QuitGame.pressed.connect(func() -> void: get_tree().quit())
	$Root/GameOverPanel/Box/MainMenu.pressed.connect(_return_to_menu)
	settings_screen.closed.connect(_close_settings)
	_fps_label = Label.new()
	_fps_label.position = Vector2(12, 12)
	_fps_label.add_theme_font_size_override("font_size", 24)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_fps_label)


func _open_settings() -> void:
	pause_menu.hide()
	settings_screen.show()
	(settings_screen.get_node("Margin/Box/Tabs") as TabContainer).get_tab_bar().grab_focus()


func _close_settings() -> void:
	pause_menu.show()
	settings_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not game_over_panel.visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_menu()
	elif event.is_action_pressed(&"reload") and not event.is_echo():
		get_viewport().set_input_as_handled()
		(get_parent() as GameSession).restart()


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://systems/ui/main_menu.tscn")

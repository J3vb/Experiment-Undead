## In-match HUD and pause menu; gameplay facts arrive through Events.
class_name Hud
extends CanvasLayer

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
@onready var round_label: Label = $Root/RoundLabel
@onready var points_label: Label = $Root/PointsLabel
@onready var points_delta: Label = $Root/PointsDelta
@onready var serums_label: Label = $Root/SerumsLabel
@onready var ammo_label: Label = $Root/AmmoLabel
@onready var weapon_label: Label = $Root/WeaponLabel
@onready var exfil_label: Label = $Root/ExfilLabel
@onready var hint_label: Label = $Root/HintLabel
@onready var center_label: Label = $Root/CenterLabel
@onready var prompt_label: Label = $Root/PromptLabel
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
	Events.exfil_opened.connect(func() -> void: _flash_center("EXFIL OPEN", 3.0))
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
	prompt_label.text = _player.focus.get_prompt(_player) if _player and _player.focus else ""
	if _player and _player.weapons.current:
		var w: Weapon = _player.weapons.current
		crosshair.spread_degrees = w.get_current_spread()
		crosshair.fov_degrees = _player.camera.fov
		crosshair.modulate.a = 0.0 if (w.ads_progress > 0.5 or _player.is_sprinting or not _player.is_alive()) else 1.0


func _update_exfil() -> void:
	if _exfil == null or not _exfil.is_holding:
		exfil_label.text = ""
		return
	var where: String = "HOLD THE HATCH" if _exfil.has_player_in_zone() else "RETURN TO THE HATCH"
	exfil_label.text = "EXFIL  %s  %d" % [where, ceili(_exfil.hold_left)]


func _flash_center(text: String, seconds: float) -> void:
	center_label.text = text
	_center_time = seconds


func _on_player_spawned(player: Player) -> void:
	if _player == null:
		_player = player


func _on_health_changed(player: Player, current: float, maximum: float) -> void:
	if player == _player:
		_health_ratio = current / maxf(maximum, 1.0)


func _on_player_damaged(player: Player, _info: DamageInfo) -> void:
	if player == _player:
		_hurt = 0.8


func _on_points_changed(player: Player, total: int, delta: int) -> void:
	if player != _player:
		return
	points_label.text = str(total)
	if delta > 0:
		_delta_sum += delta
		points_delta.text = "+%d" % _delta_sum
		_delta_time = 1.2


func _on_ammo_changed(player: Player, in_mag: int, reserve: int) -> void:
	if player != _player:
		return
	ammo_label.text = "%d / %d" % [in_mag, reserve]
	var low: bool = _player.weapons.current and in_mag <= _player.weapons.current.data.magazine_size / 4
	ammo_label.modulate = Color(1, 0.3, 0.25) if low else Color.WHITE
	if in_mag == 0 and reserve == 0:
		hint_label.text = "NO AMMO"
	elif low and reserve > 0:
		hint_label.text = "RELOAD [R]"
	else:
		hint_label.text = ""


func _on_weapon_switched(player: Player, weapon: Weapon) -> void:
	if player == _player:
		weapon_label.text = weapon.data.display_name.to_upper()


func _on_serum_gained(player: Player, _serum: SerumData) -> void:
	if player != _player:
		return
	var names: PackedStringArray = []
	for serum: SerumData in player.serums:
		names.append(serum.display_name.to_upper())
	serums_label.text = "  ".join(names)


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
		_on_serum_gained(player, null)


func _on_round_started(round_number: int, _count: int) -> void:
	round_label.text = str(round_number)
	_flash_center("ROUND %d" % round_number, 3.0)
	round_sound.play()


func _on_round_ended(round_number: int) -> void:
	_flash_center("ROUND %d SURVIVED" % round_number, 3.0)


func _on_intermission(next_round: int, duration: float) -> void:
	if next_round == 1:
		_flash_center("SURVIVE", duration)


func _on_game_over(stats: Dictionary) -> void:
	game_over_panel.visible = true
	game_over_stats.text = (
		("Exfil successful: +50% XP\n" if stats.get("exfil", false) else "")
		+ (
			"You survived %d round%s\n%d kills    %d points    %d XP\n\nPress ENTER to try again"
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
	resume_button.pressed.connect(func() -> void: (get_parent() as GameSession).resume())
	settings_button.pressed.connect(_open_settings)
	$Root/PausePanel/Menu/Quit.pressed.connect(func() -> void: get_tree().quit())
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

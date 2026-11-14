## HUD presentation follows Events without changing gameplay state.
extends GutTest

const HUD: PackedScene = preload("res://systems/ui/hud.tscn")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var hud: Hud
var player: Player


func before_each() -> void:
	hud = HUD.instantiate() as Hud
	add_child_autofree(hud)
	hud.set_process(false)
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.weapons.give(Content.weapon(&"rifle_ar"))
	Events.player_spawned.emit(player)


func test_round_starts_white_and_intermission_blinks() -> void:
	Events.round_started.emit(12, 24)
	assert_eq(hud.round_label.text, "12")
	assert_eq(hud.round_label.modulate, Color.WHITE)
	hud._round_tween.pause()
	hud._round_tween.custom_step(1.1)
	assert_eq(hud.round_label.modulate, Hud.BLOOD_RED)
	Events.intermission_started.emit(13, 10.0)
	hud._round_tween.pause()
	hud._round_tween.custom_step(0.8)
	assert_almost_eq(hud.round_label.modulate.a, 0.3, 0.001)
	Events.round_started.emit(13, 26)
	assert_eq(hud.round_label.modulate.a, 1.0)


func test_points_separators_and_delta_summing_then_expiry() -> void:
	Events.points_changed.emit(player, 14520, 100)
	Events.points_changed.emit(player, 14570, 50)
	assert_eq(hud.points_label.text, "14,570")
	assert_eq(hud.points_delta.text, "+150")
	hud._process(1.3)
	assert_eq(hud.points_delta.modulate.a, 0.0)
	Events.points_changed.emit(player, 14670, 100)
	assert_eq(hud.points_delta.text, "+100")
	Events.points_changed.emit(player, 999, -13671)
	assert_eq(hud.points_label.text, "999")


func test_ammo_threshold_and_hints() -> void:
	var magazine: int = player.weapons.current.data.magazine_size
	var low_count: int = floori(magazine * 0.25)
	Events.ammo_changed.emit(player, low_count, 210)
	assert_eq(hud.ammo_label.text, str(low_count))
	assert_eq(hud.reserve_label.text, "/ 210")
	assert_eq(hud.ammo_label.modulate, Hud.BLOOD_RED)
	assert_eq(hud.hint_label.text, "RELOAD [R]")
	Events.ammo_changed.emit(player, low_count + 1, 210)
	assert_eq(hud.ammo_label.modulate, Hud.OFF_WHITE)
	assert_eq(hud.hint_label.text, "")
	Events.ammo_changed.emit(player, 0, 0)
	assert_eq(hud.hint_label.text, "NO AMMO")
	Events.weapon_switched.emit(player, player.weapons.current)
	assert_eq(hud.weapon_label.text, player.weapons.current.data.display_name)


func test_serum_codes_are_unique_coloured_squares() -> void:
	for id: StringName in Hud.SERUM_STYLES:
		var serum: SerumData = SerumData.new()
		serum.id = id
		Events.serum_gained.emit(player, serum)
		Events.serum_gained.emit(player, serum)
		var badge: Label = hud.serums.get_node(NodePath(id)) as Label
		assert_eq(badge.text, Hud.SERUM_STYLES[id][0])
		assert_eq((badge.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Hud.SERUM_STYLES[id][1])
	assert_eq(hud.serums.get_child_count(), 8)


func test_exfil_shows_when_open_counts_hold_and_hides_when_closed() -> void:
	var hatch: ExfilHatch = preload("res://systems/interactables/exfil_hatch.tscn").instantiate() as ExfilHatch
	add_child_autofree(hatch)
	assert_false(hud.exfil_box.visible)
	hatch.is_open = true
	Events.exfil_opened.emit()
	assert_true(hud.exfil_box.visible)
	assert_eq(hud.exfil_title.text, "Exfil open · Containment Wing")
	hatch.is_holding = true
	hatch.hold_left = 39.0
	Events.exfil_called.emit(hatch)
	hud._process(0.0)
	assert_eq(hud.exfil_time.text, "Hold 0:39")
	assert_almost_eq(hud.exfil_bar.value, 0.35, 0.001)
	hatch.is_open = false
	hatch.is_holding = false
	hud._process(0.0)
	assert_false(hud.exfil_box.visible)


func test_prompt_splits_existing_interactable_price_and_preserves_unclear_text() -> void:
	var door: Door = Door.new()
	autofree(door)
	door.cost = 1500
	door.label = "Labs"
	player.focus = door
	hud._process(0.0)
	assert_true(hud.prompt_box.visible)
	assert_true(hud.prompt_key.visible)
	assert_eq(hud.prompt_label.text, "Open Labs")
	assert_eq(hud.prompt_price.text, "1500")
	await get_tree().process_frame
	assert_gt(hud.prompt_box.position.y, hud.prompt_box.get_viewport_rect().size.y * 0.5)
	hud._update_prompt("Needs power")
	assert_eq(hud.prompt_label.text, "Needs power")
	assert_eq(hud.prompt_price.text, "")
	assert_false(hud.prompt_key.visible)
	hud._update_prompt("Buy Rifle 42 [F]  unknown")
	assert_eq(hud.prompt_label.text, "Buy Rifle 42   unknown")
	assert_eq(hud.prompt_price.text, "")
	player.focus = null
	hud._process(0.0)
	assert_false(hud.prompt_box.visible)


func test_health_bar_threshold_and_other_player_events_ignored() -> void:
	Events.player_health_changed.emit(player, 30.0, 100.0)
	assert_almost_eq(hud.health_bar.value, 0.3, 0.001)
	assert_eq(hud.health_bar.modulate, Hud.OFF_WHITE)
	Events.player_health_changed.emit(player, 29.0, 100.0)
	assert_eq(hud.health_bar.modulate, Hud.BLOOD_RED)
	var other: Player = Player.new()
	autofree(other)
	Events.player_health_changed.emit(other, 100.0, 100.0)
	Events.points_changed.emit(other, 99999, 100)
	assert_almost_eq(hud.health_bar.value, 0.29, 0.001)
	assert_eq(hud.points_label.text, "0")


func test_revive_removes_consumed_serum_badge() -> void:
	var ironhide: SerumData = load("res://content/serums/ironhide.tres") as SerumData
	var second_wind: SerumData = load("res://content/serums/second_wind.tres") as SerumData
	player.serums.append(ironhide)
	player.serums.append(second_wind)
	Events.serum_gained.emit(player, ironhide)
	Events.serum_gained.emit(player, second_wind)
	player.serums.erase(second_wind)
	Events.player_revived.emit(player)
	await get_tree().process_frame
	assert_eq(hud.serums.get_child_count(), 1)
	assert_eq((hud.serums.get_child(0) as Label).text, "IH")

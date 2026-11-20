## WeaponPanel shows the local player's ammo, gun icon and frag count (frag checks moved from
## the old GrenadeSlot test, frag-grenades plan step 3).
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player
var panel: WeaponPanel


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.weapons.give(Content.weapon(&"rifle_ar"))
	panel = WeaponPanel.new()
	panel.size = Vector2(460, 80)
	add_child_autofree(panel)
	Events.player_spawned.emit(player)


func test_ammo_text_and_colours() -> void:
	var magazine: int = player.weapons.current.data.magazine_size
	Events.ammo_changed.emit(player, magazine, 210)
	assert_eq(panel.ammo_label.text, str(magazine))
	assert_eq(panel.reserve_label.text, "/ 210")
	assert_eq(panel.ammo_label.get_theme_color("font_color"), WeaponPanel.TEXT)
	Events.ammo_changed.emit(player, magazine / 4, 210)
	assert_eq(panel.ammo_label.get_theme_color("font_color"), WeaponPanel.WARN, "a quarter left is orange")
	Events.ammo_changed.emit(player, 0, 210)
	assert_eq(panel.ammo_label.get_theme_color("font_color"), WeaponPanel.DANGER, "empty is red")


func test_other_players_ammo_ignored() -> void:
	var other: Player = Player.new()
	autofree(other)
	Events.ammo_changed.emit(other, 7, 7)
	assert_eq(panel.ammo_label.text, "0")


func test_icon_follows_weapon_switch() -> void:
	Events.weapon_switched.emit(player, player.weapons.current)
	assert_eq(panel.icon(), player.weapons.current.data.hud_icon)
	assert_not_null(panel.icon())


func test_frag_count_follows_the_player() -> void:
	player.grenades.count = 2
	panel._process(0.0)
	assert_eq(panel.shown_count, 2)
	assert_eq(panel.frag_label.text, "2")
	assert_false(panel.dimmed())


func test_frag_dims_at_zero() -> void:
	player.grenades.count = 0
	panel._process(0.0)
	assert_true(panel.dimmed())
	assert_almost_eq(panel.frag_label.get_theme_color("font_color").a, WeaponPanel.EMPTY_ALPHA, 0.001)


func test_frag_shows_cooking() -> void:
	player.grenades.count = 1
	player.grenades.cooking = true
	panel._process(0.0)
	assert_true(panel.shown_cooking)
	assert_eq(panel.frag_label.get_theme_color("font_color"), WeaponPanel.WARN)


func test_key_text_follows_the_binding() -> void:
	assert_eq(panel.key_text, Settings.key_name(&"lethal"))
	panel.key_text = ""
	Settings.changed.emit(&"bindings", &"lethal", null)
	assert_eq(panel.key_text, Settings.key_name(&"lethal"), "rebinding updates the key")


func test_no_local_player_draws_without_errors() -> void:
	var lonely: WeaponPanel = WeaponPanel.new()
	lonely.size = Vector2(460, 80)
	add_child_autofree(lonely)
	lonely._process(0.0)
	await wait_process_frames(1)
	assert_true(lonely.dimmed())
	assert_true(lonely._warned.is_empty())

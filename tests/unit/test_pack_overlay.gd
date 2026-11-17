## Pack HUD updates, tooltip inspection, quick equip and personal discard.
extends GutTest

const HUD: PackedScene = preload("res://systems/ui/hud.tscn")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var overlay: PackOverlay
var service: LootService
var player: Player
var session: GameSession


func before_each() -> void:
	var hud: Hud = HUD.instantiate() as Hud
	add_child_autofree(hud)
	overlay = hud.get_node("Root/Pack") as PackOverlay
	session = GameSession.new()
	session.rng.seed = 73
	autofree(session)
	service = LootService.new()
	service.session = session
	add_child_autofree(service)
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	service.player = player
	overlay.setup(service)


func test_changed_updates_all_six_slots_and_tooltip() -> void:
	assert_eq(overlay.count.text, "Pack 0 / 6 [Tab]")
	service.pack.add({"uid": "gear", "base": "vest_light", "rar": "epic", "ilvl": 17})
	assert_eq(overlay.count.text, "Pack 1 / 6 [Tab]")
	assert_eq(overlay.slots.size(), 6)
	assert_string_contains(overlay.slots[0].text, "Lantern Rig")
	assert_eq(overlay.slots[5].text, "Empty")
	assert_eq(overlay.slots[0].get_theme_color("font_color"), Color("a64dff"))
	assert_eq(overlay.tooltip.item_name.text, "Lantern Rig")
	assert_string_contains(overlay.feed.text, "Epic Lantern Rig")
	overlay._process(4.1)
	assert_eq(overlay.feed.modulate.a, 0.0)


func test_tab_keeps_simulation_and_movement_enabled_and_escape_closes() -> void:
	var tab: InputEventKey = InputEventKey.new()
	tab.pressed = true
	tab.physical_keycode = KEY_TAB
	overlay._input(tab)
	assert_true(overlay.panel.visible)
	assert_false(get_tree().paused)
	assert_true(player.input_enabled)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(100, 50)
	overlay._input(motion)
	assert_true(get_viewport().is_input_handled(), "overlay blocks mouse look input")
	var escape: InputEventKey = InputEventKey.new()
	escape.pressed = true
	escape.physical_keycode = KEY_ESCAPE
	overlay._input(escape)
	assert_false(overlay.panel.visible)


func test_pack_gun_equips_once_and_stays_available_for_stash_banking() -> void:
	var item: Dictionary = ItemRoller.roll_weapon(session.rng, Content.weapon(&"rifle_ar"), &"rare", 17)
	service.pack.add(item)
	overlay._equip()
	assert_eq(player.weapons.current.item.data, item)
	assert_eq(service.pack.items, [item])
	overlay._equip()
	assert_eq(player.weapons.weapons.size(), 1, "reselecting equips the same run weapon")


func test_discard_recreates_only_a_personal_drop() -> void:
	var item: Dictionary = {"uid": "discard", "base": "vest_light", "rar": "rare"}
	service.pack.add(item)
	overlay._drop()
	assert_true(service.pack.items.is_empty())
	assert_eq(service.get_child_count(), 1)
	var drop: LootDrop = service.get_child(0) as LootDrop
	assert_eq(drop.item, item)
	assert_eq(drop.player, player)


func test_replaced_pack_guns_restore_ammo_including_an_empty_gun() -> void:
	player.weapons.give(Content.weapon(&"pistol_service"))
	player.weapons.give(Content.weapon(&"rifle_ar"))
	for base: StringName in [&"rifle_ar", &"kestrel_smg"]:
		service.pack.add(ItemRoller.roll_weapon(session.rng, Content.weapon(base), &"rare", 17))
	overlay._select(0)
	overlay._equip()
	player.weapons.current.instance.ammo_in_mag = 2
	player.weapons.current.instance.ammo_reserve = 7
	overlay._select(1)
	overlay._equip()
	player.weapons.current.instance.ammo_in_mag = 3
	player.weapons.current.instance.ammo_reserve = 9
	overlay._select(0)
	overlay._equip()
	assert_eq(player.weapons.current.instance.ammo_in_mag, 2)
	assert_eq(player.weapons.current.instance.ammo_reserve, 7)
	player.weapons.current.instance.ammo_in_mag = 0
	player.weapons.current.instance.ammo_reserve = 0
	overlay._select(1)
	overlay._equip()
	assert_eq(player.weapons.current.instance.ammo_in_mag, 3)
	assert_eq(player.weapons.current.instance.ammo_reserve, 9)
	watch_signals(Events)
	overlay._select(0)
	overlay._equip()
	assert_eq(player.weapons.current.instance.ammo_in_mag, 0)
	assert_eq(player.weapons.current.instance.ammo_reserve, 0)
	assert_eq(player.weapons.weapons.size(), 2)
	assert_signal_emitted_with_parameters(Events, "ammo_changed", [player, 0, 0])


func test_open_pack_frees_the_mouse_and_closing_gives_it_back() -> void:
	var root: ScreenData = UI._root
	UI._root = Content.get_item(&"screens", &"match") as ScreenData
	assert_false(UI.mouse_should_be_free())
	overlay.set_open(true)
	assert_true(UI.mouse_should_be_free(), "mouse look pauses while the Pack is open")
	overlay.set_open(false)
	assert_false(UI.mouse_should_be_free())
	UI._root = root

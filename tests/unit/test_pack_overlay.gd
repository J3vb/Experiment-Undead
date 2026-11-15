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

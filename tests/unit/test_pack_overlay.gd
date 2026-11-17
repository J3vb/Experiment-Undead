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
	assert_eq(player.weapons.weapons.size(), 0, "the key handler only asks; nothing changes yet")
	await wait_physics_frames(2)
	assert_eq(player.weapons.current.item.data, item)
	assert_eq(service.pack.items, [item])
	player.weapons.give(Content.weapon(&"pistol_service"))
	overlay._equip()
	await wait_physics_frames(2)
	assert_eq(player.weapons.weapons.size(), 2, "reselecting equips the same run weapon")
	assert_eq(player.weapons.current.item.data, item, "the Pack gun is back in hand")


func test_solo_pack_leech_gun_heals_through_the_server_hit_path() -> void:
	var item: Dictionary = {"v": 1, "uid": "pack_leech", "base": "rifle_ar", "rar": "rare", "aff": [["leech", 5, 1.0]]}
	service.pack.add(item)
	overlay._equip()
	await wait_physics_frames(2)
	assert_true(player.item_guns.has("pack_leech"))
	player.health.current = 50.0
	var info: DamageInfo = DamageInfo.create(10.0, player)
	info.item_uid = "pack_leech"
	Events.enemy_damaged.emit(null, info)
	assert_eq(player.health.current, 53.0)


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
	await wait_physics_frames(2)
	player.weapons.current.instance.ammo_in_mag = 2
	player.weapons.current.instance.ammo_reserve = 7
	overlay._select(1)
	overlay._equip()
	await wait_physics_frames(2)
	player.weapons.current.instance.ammo_in_mag = 3
	player.weapons.current.instance.ammo_reserve = 9
	overlay._select(0)
	overlay._equip()
	await wait_physics_frames(2)
	assert_eq(player.weapons.current.instance.ammo_in_mag, 2)
	assert_eq(player.weapons.current.instance.ammo_reserve, 7)
	player.weapons.current.instance.ammo_in_mag = 0
	player.weapons.current.instance.ammo_reserve = 0
	overlay._select(1)
	overlay._equip()
	await wait_physics_frames(2)
	assert_eq(player.weapons.current.instance.ammo_in_mag, 3)
	assert_eq(player.weapons.current.instance.ammo_reserve, 9)
	watch_signals(Events)
	overlay._select(0)
	overlay._equip()
	await wait_physics_frames(2)
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


func test_pack_keys_are_input_actions_so_rebinding_moves_them() -> void:
	var saved: Array[InputEvent] = InputMap.action_get_events(&"pack_toggle")
	InputMap.action_erase_events(&"pack_toggle")
	var rebound: InputEventKey = InputEventKey.new()
	rebound.physical_keycode = KEY_I
	InputMap.action_add_event(&"pack_toggle", rebound)
	overlay._input(_key(KEY_TAB))
	assert_false(overlay.panel.visible, "the old key no longer opens the Pack")
	overlay._input(_key(KEY_I))
	assert_true(overlay.panel.visible, "the rebound key opens it")
	assert_eq(PackOverlay.key_name(&"pack_toggle"), "I", "labels follow the binding")
	InputMap.action_erase_events(&"pack_toggle")
	for event: InputEvent in saved:
		InputMap.action_add_event(&"pack_toggle", event)
	assert_eq(PackOverlay.key_name(&"pack_toggle"), "Tab")


func test_drop_and_equip_keys_go_through_their_actions() -> void:
	var item: Dictionary = ItemRoller.roll_weapon(session.rng, Content.weapon(&"rifle_ar"), &"rare", 17)
	service.pack.add(item)
	overlay._input(_key(KEY_E))
	await wait_physics_frames(2)
	assert_eq(player.weapons.weapons.size(), 0, "closed Pack ignores the equip key")
	overlay.set_open(true)
	overlay._input(_key(KEY_E))
	await wait_physics_frames(2)
	assert_eq(player.weapons.current.item.data, item)
	overlay._input(_key(KEY_G))
	assert_true(service.pack.items.is_empty(), "the drop key removes the selected item")
	overlay.set_open(false)


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	return event


func _click(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.pressed = true
	event.button_index = button
	return event


func test_pack_actions_rebound_to_mouse_buttons_work_and_relabel() -> void:
	var old_path: String = Settings.config_path
	Settings.config_path = "user://test_pack_bindings.cfg"
	service.pack.add(ItemRoller.roll_weapon(session.rng, Content.weapon(&"rifle_ar"), &"rare", 17))
	service.pack.add(ItemRoller.roll_weapon(session.rng, Content.weapon(&"rifle_ar"), &"rare", 17))
	Settings.set_binding(&"pack_toggle", 0, _click(MOUSE_BUTTON_XBUTTON1))
	Settings.set_binding(&"pack_drop", 0, _click(MOUSE_BUTTON_XBUTTON2))
	Settings.set_binding(&"pack_equip", 0, _click(MOUSE_BUTTON_MIDDLE))
	assert_eq(overlay.close_button.text, "Mouse 4 · Close", "built labels follow a rebind")
	assert_eq(overlay.drop_button.text, "Mouse 5 · Drop")
	assert_eq(overlay.equip_button.text, "Middle mouse · Into hands")
	assert_eq(overlay.count.text, "Pack 2 / 6 [Mouse 4]")
	overlay._input(_click(MOUSE_BUTTON_XBUTTON1))
	assert_true(overlay.panel.visible, "a mouse button opens the Pack")
	overlay._input(_click(MOUSE_BUTTON_XBUTTON2))
	assert_eq(service.pack.items.size(), 1, "a mouse button drops")
	var kept: Dictionary = service.pack.items[0]
	overlay._input(_click(MOUSE_BUTTON_MIDDLE))
	await wait_physics_frames(2)
	assert_eq(player.weapons.current.item.data, kept, "a mouse button equips")
	for action: StringName in [&"pack_toggle", &"pack_drop", &"pack_equip"]:
		Settings.reset_binding(action)
	assert_eq(overlay.close_button.text, "Tab · Close")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.config_path))
	Settings.config_path = old_path

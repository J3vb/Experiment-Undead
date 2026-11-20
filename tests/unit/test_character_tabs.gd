## Loadout tabs (F-88 step 3): Weapons and Field Gear split the slots and the stash; the other three are locked.
extends GutTest

const SCREEN: PackedScene = preload("res://systems/ui/character_screen.tscn")

var screen: CharacterScreen
var profile: CharacterProfile


func before_each() -> void:
	profile = CharacterProfile.new()
	profile.id = &"test_character_tabs"
	profile.stash[0] = _item("rifle_ar", "rifle", "common")
	profile.stash[1] = _item("vest_medium", "vest", "rare")
	profile.stash[2] = _item("charm_dog_tags", "charm", "epic")
	profile.stash[3] = _item("pistol_service", "pistol", "rare")
	screen = SCREEN.instantiate() as CharacterScreen
	add_child_autofree(screen)
	screen.open(profile)


func test_weapons_is_the_default_and_shows_only_gun_slots_and_guns() -> void:
	assert_eq(screen.tab, &"weapons")
	assert_true(screen.tabs.button_for(&"weapons").button_pressed)
	assert_eq(_visible_slot_ids(), [&"primary", &"sidearm"])
	assert_eq(screen.visible_stash_indices(), [3, 0])


func test_field_gear_shows_the_other_slots_and_gear() -> void:
	var field_gear: Button = screen.tabs.button_for(&"field_gear")
	field_gear.button_pressed = true
	field_gear.pressed.emit()
	assert_false(field_gear.button_group.allow_unpress, "clicking the open tab again keeps it open")
	assert_eq(screen.tab, &"field_gear")
	assert_true(screen.tabs.button_for(&"field_gear").button_pressed)
	assert_false(screen.tabs.button_for(&"weapons").button_pressed)
	assert_eq(_visible_slot_ids(), [&"vest", &"charm", &"implant"])
	assert_eq(screen.visible_stash_indices(), [2, 1])


func test_equip_from_field_gear_then_back_to_weapons() -> void:
	screen.select_tab(&"field_gear")
	_stash_button(1).grab_focus()
	screen._input(_key(KEY_E))
	assert_eq(profile.loadout[&"vest"].get("uid"), "vest")
	screen.select_tab(&"weapons")
	_stash_button(0).grab_focus()
	screen._input(_key(KEY_E))
	assert_eq(profile.loadout[&"primary"].get("uid"), "rifle")


func test_locked_tabs_are_greyed_and_do_nothing() -> void:
	for id: StringName in [&"serums", &"perks", &"customize"]:
		var button: Button = screen.tabs.button_for(id)
		assert_true(button.disabled, String(id))
		assert_eq(button.focus_mode, Control.FOCUS_NONE)
		assert_eq(button.tooltip_text, "Coming soon")
		screen.select_tab(id)
		assert_eq(screen.tab, &"weapons", "a locked tab never opens")
	var labels: Array[String] = []
	for button: Button in screen.tabs.buttons:
		labels.append(button.text)
	assert_eq(labels, ["WEAPONS", "SERUMS", "PERKS", "FIELD GEAR", "CUSTOMIZE"])


func test_focus_only_points_at_visible_controls_after_each_tab_change() -> void:
	for id: StringName in [&"field_gear", &"weapons", &"field_gear"]:
		screen.select_tab(id)
		var controls: Array[Control] = []
		controls.append_array(screen.tabs.open_buttons())
		controls.append_array(screen.slot_buttons.filter(func(button: Button) -> bool: return button.visible))
		controls.append_array(screen.stash_buttons)
		controls.append_array([screen.get_node("%Rarity"), screen.get_node("%Sort"), screen.get_node("%Back")])
		for control: Control in controls:
			for path: NodePath in [
				control.focus_neighbor_top,
				control.focus_neighbor_bottom,
				control.focus_neighbor_left,
				control.focus_neighbor_right,
				control.focus_next,
				control.focus_previous
			]:
				if path.is_empty():
					continue
				var target: Control = control.get_node(path) as Control
				assert_true(target.visible and target.focus_mode != Control.FOCUS_NONE, "%s -> %s" % [control, target])


func test_reopening_starts_on_weapons() -> void:
	screen.select_tab(&"field_gear")
	screen.open(profile)
	assert_eq(screen.tab, &"weapons")
	assert_eq(_visible_slot_ids(), [&"primary", &"sidearm"])


func test_loadout_tabs_lists_all_five_and_opens_only_two() -> void:
	assert_eq(LoadoutTabs.TABS.size(), 5)
	assert_eq(screen.tabs.open_buttons().size(), 2)
	assert_true(screen.tabs.button_for(&"serums").disabled)


func test_character_stash_puts_items_with_a_missing_base_under_field_gear() -> void:
	profile.stash[4] = _item("gone_from_content", "gone", "common")
	var gear: Array[int] = CharacterStash.visible_indices(
		profile, CharacterStash.Kind.GEAR, 0, CharacterStash.Order.RARITY
	)
	assert_true(gear.has(4))
	var guns: Array[int] = CharacterStash.visible_indices(
		profile, CharacterStash.Kind.WEAPONS, 0, CharacterStash.Order.RARITY
	)
	assert_false(guns.has(4))


func _visible_slot_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for button: Button in screen.slot_buttons:
		if button.visible:
			ids.append(button.get_meta("slot"))
	return ids


func _stash_button(index: int) -> Button:
	for button: Button in screen.stash_buttons:
		if button.get_meta("stash_index", -1) == index:
			return button
	return null


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _item(base: String, uid: String, rarity: String) -> Dictionary:
	return {"v": 1, "uid": uid, "base": base, "rar": rarity, "ilvl": 10, "aff": [], "imp": []}

## Character loadout requests, stash presentation, turntable updates and close-time persistence.
extends GutTest

const SCREEN: PackedScene = preload("res://systems/ui/character_screen.tscn")
const PROFILE_ID: StringName = &"test_character_screen"

var screen: CharacterScreen
var profile: CharacterProfile
var _profile_path: String = CharacterProfile.directory() + "test_character_screen.json"


func before_each() -> void:
	_remove_save()
	profile = CharacterProfile.new()
	profile.id = PROFILE_ID
	profile.display_name = "Rook"
	profile.total_xp = CharacterProfile.XP_RULES.total_xp_for_level(14)
	profile.stash[0] = _item("rifle_ar", "old", "common", 8)
	profile.stash[4] = _item("pistol_service", "sidearm", "rare", 21)
	profile.stash[9] = _item("talon_dmr", "new", "epic", 17)
	screen = SCREEN.instantiate() as CharacterScreen
	add_child_autofree(screen)
	screen.open(profile)


func after_each() -> void:
	_remove_save()


func test_open_shows_profile_slots_stash_and_default_focus() -> void:
	assert_eq(screen.profile, profile)
	assert_eq((screen.get_node("%Name") as NameField).text, "Rook")
	assert_string_contains((screen.get_node("%Level") as Label).text, "14")
	assert_eq(screen.stash_buttons.size(), 60)
	assert_eq(screen.slots.buttons.size(), 9)
	assert_eq((screen.get_node("%Grid") as GridContainer).columns, CharacterScreen.STASH_COLUMNS)
	assert_true(screen.is_ancestor_of(screen.get_viewport().gui_get_focus_owner()))
	assert_eq(screen.get_theme_font("font"), (screen.get_node("%ItemTooltip") as Control).get_theme_font("font"))
	assert_not_null(screen.rig.skeleton)
	assert_false(FileAccess.file_exists(_profile_path), "Opening does not write a save")


func test_e_equips_selected_stash_item_then_unequips_loadout() -> void:
	var chosen: Dictionary = profile.stash[4].duplicate(true)
	_stash_button(4).grab_focus()
	screen._input(_key(KEY_E))
	assert_eq(profile.loadout[&"sidearm"], chosen)
	assert_eq(profile.stash[4], {})
	_slot_button(&"sidearm").grab_focus()
	screen._input(_key(KEY_E))
	assert_eq(profile.loadout[&"sidearm"], {})
	assert_true(profile.stash.has(chosen))
	assert_false(FileAccess.file_exists(_profile_path), "Equipment saves on close")


func test_equipment_request_reapplies_rig_and_removes_unequipped_vest() -> void:
	profile.loadout[&"vest"] = _item("vest_medium", "vest", "rare", 17)
	screen.open(profile)
	var old_vest: Node = screen.rig.skeleton.get_node("Vest")
	assert_not_null(old_vest)
	_stash_button(0).grab_focus()
	screen._input(_key(KEY_E))
	assert_false(is_instance_valid(old_vest), "Equipping refreshes GearRig from the current loadout")
	assert_not_null(screen.rig.skeleton.get_node_or_null("Vest"))
	_slot_button(&"vest").grab_focus()
	screen._input(_key(KEY_E))
	assert_eq(profile.loadout[&"vest"], {})
	assert_null(screen.rig.skeleton.get_node_or_null("Vest"))


func test_vest_charm_and_implant_equip_and_unequip_through_inventory_and_rig() -> void:
	var bases: Array[StringName] = [&"vest_medium", &"charm_dog_tags", &"implant_reflex"]
	for index: int in bases.size():
		var slot: StringName = CharacterLook.SLOTS[index]
		var item: Dictionary = _item(String(bases[index]), "worn_" + String(slot), "rare", 14)
		profile.stash[20 + index] = item
		screen.open(profile)
		_stash_button(20 + index).grab_focus()
		screen._input(_key(KEY_E))
		assert_eq(profile.loadout[slot], item)
		assert_eq(profile.stash[20 + index], {})
		assert_not_null(screen.rig.skeleton.get_node_or_null(String(slot).capitalize()))
		var base: GearBaseData = Content.get_item(&"loot", bases[index]) as GearBaseData
		assert_string_contains(_slot_button(slot).text, base.display_name)
		_slot_button(slot).grab_focus()
		screen._input(_key(KEY_E))
		assert_eq(profile.loadout[slot], {})
		assert_true(profile.stash.has(item))
		assert_null(screen.rig.skeleton.get_node_or_null(String(slot).capitalize()))


func test_double_click_equips_and_hover_inspects_item() -> void:
	var button: Button = _stash_button(9)
	button.mouse_entered.emit()
	assert_eq((screen.get_node("%ItemTooltip") as ItemTooltip).item_name.text, "MR-28")
	var double_click: InputEventMouseButton = InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	button.gui_input.emit(double_click)
	assert_eq(profile.loadout[&"primary"].get("uid"), "new")
	assert_eq(profile.stash[9], {})


func test_controller_a_equips_focused_item_after_mouse_hover_inspects_another() -> void:
	_stash_button(4).grab_focus()
	_stash_button(0).mouse_entered.emit()
	assert_eq(screen.selected_stash, 0, "Mouse hover temporarily inspects another item")
	var accept: InputEventJoypadButton = InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	screen._input(accept)
	assert_eq(profile.loadout[&"sidearm"].get("uid"), "sidearm")
	assert_eq(profile.loadout[&"primary"], {})
	assert_eq(profile.stash[0].get("uid"), "old")


func test_drag_rotates_turntable_and_releasing_outside_preview_stops_rotation() -> void:
	var preview: Control = screen.get_node("%Preview") as Control
	var turntable: Node3D = screen.get_node("%Turntable") as Node3D
	var start: float = turntable.rotation.y
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	preview.gui_input.emit(mouse)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(20.0, 0.0)
	preview.gui_input.emit(motion)
	assert_gt(turntable.rotation.y, start)
	var dragged: float = turntable.rotation.y
	mouse.pressed = false
	screen._input(mouse)
	preview.gui_input.emit(motion)
	assert_almost_eq(turntable.rotation.y, dragged, 0.0001)


func test_filters_combine_category_and_rarity_without_mutating_items() -> void:
	profile.stash[14] = _item("vest_medium", "gear", "rare", 30)
	screen.open(profile)
	var before: Dictionary = profile.to_dict()
	_choose("Category", 1)
	assert_eq(screen.visible_stash_indices(), [9, 4, 0])
	_choose("Rarity", 3)
	assert_eq(screen.visible_stash_indices(), [4])
	_choose("Category", 2)
	assert_eq(screen.visible_stash_indices(), [14])
	_choose("Rarity", 5)
	assert_eq(screen.visible_stash_indices(), [])
	assert_eq(profile.to_dict(), before)


func test_sorts_use_rarity_item_level_and_legacy_newest_order() -> void:
	assert_eq(screen.visible_stash_indices(), [9, 4, 0])
	_choose("Sort", 1)
	assert_eq(screen.visible_stash_indices(), [4, 9, 0])
	_choose("Sort", 2)
	assert_eq(screen.visible_stash_indices(), [9, 4, 0])
	assert_eq(profile.stash[0].uid, "old", "Sort changes presentation rather than saved stash positions")


func test_newest_sort_uses_acquisition_order_after_reusing_a_stash_hole() -> void:
	Inventory.remove(profile, 0)
	assert_eq(Inventory.add_to_stash(profile, _item("rifle_ar", "fresh", "common", 1)), 0)
	var acquired: int = int(profile.stash[0].get("acquired", -1))
	assert_gt(acquired, 9, "The new item is newer than every legacy stash position")
	screen.open(profile)
	_choose("Sort", 2)
	assert_eq(screen.visible_stash_indices(), [0, 9, 4])
	_stash_button(0).grab_focus()
	screen._input(_key(KEY_E))
	assert_eq(profile.loadout[&"primary"].get("uid"), "fresh")
	assert_eq(profile.loadout[&"primary"].get("acquired"), acquired)
	_slot_button(&"primary").grab_focus()
	screen._input(_key(KEY_E))
	assert_eq(profile.stash[0].get("uid"), "fresh")
	assert_eq(profile.stash[0].get("acquired"), acquired, "Equipment moves preserve acquisition order")
	assert_eq(screen.visible_stash_indices(), [0, 9, 4])


func test_shift_holds_compare_and_controller_x_toggles_it() -> void:
	profile.loadout[&"primary"] = _item("rifle_ar", "equipped", "common", 8)
	screen.open(profile)
	_stash_button(9).grab_focus()
	var shift: InputEventKey = _key(KEY_SHIFT)
	screen._input(shift)
	var value: Label = screen.tooltip.stats.get_child(0).get_child(2) as Label
	assert_string_contains(value.text, "↑")
	shift.pressed = false
	screen._input(shift)
	value = screen.tooltip.stats.get_child(0).get_child(2) as Label
	assert_false(value.text.contains("↑"))
	var compare: InputEventJoypadButton = InputEventJoypadButton.new()
	compare.button_index = JOY_BUTTON_X
	compare.pressed = true
	screen._input(compare)
	assert_string_contains(screen.tooltip.comparison.text, "(equipped)")
	screen._input(compare)
	assert_false(screen.tooltip.comparison.text.contains("(equipped)"))


func test_stash_focus_moves_across_cells_rows_and_back_to_controls() -> void:
	var first: Button = screen.stash_buttons[0]
	assert_eq(first.get_node(first.focus_neighbor_right), screen.stash_buttons[1])
	assert_eq(first.get_node(first.focus_neighbor_bottom), screen.stash_buttons[CharacterScreen.STASH_COLUMNS])
	assert_eq(first.get_node(first.focus_neighbor_left), _slot_button(&"primary"))
	assert_eq(first.get_node(first.focus_neighbor_top), screen.get_node("%Sort"))
	var last: Button = screen.stash_buttons[59]
	assert_eq(last.get_node(last.focus_neighbor_bottom), screen.get_node("%Back"))
	assert_eq(last.get_node(last.focus_next), screen.get_node("%Back"))
	assert_eq(
		(screen.get_node("%Back") as Button).get_node((screen.get_node("%Back") as Button).focus_next),
		_slot_button(&"headgear")
	)


func test_unknown_item_and_full_stash_unequip_are_rejected_without_changes() -> void:
	profile.stash[0] = _item("missing_base", "unknown", "rare", 1)
	screen.open(profile)
	var before: Dictionary = profile.to_dict()
	_stash_button(0).grab_focus()
	screen._input(_key(KEY_E))
	assert_eq(profile.to_dict(), before)
	assert_false((screen.get_node("%Status") as Label).text.is_empty())
	for index: int in 60:
		profile.stash[index] = _item("rifle_ar", str(index), "common", 1)
	profile.loadout[&"primary"] = _item("talon_dmr", "equipped", "epic", 20)
	screen.open(profile)
	before = profile.to_dict()
	_slot_button(&"primary").grab_focus()
	screen._input(_key(KEY_E))
	assert_eq(profile.to_dict(), before)
	assert_false((screen.get_node("%Status") as Label).text.is_empty())


func test_close_saves_equipment_and_profile_before_emitting_closed() -> void:
	_stash_button(4).grab_focus()
	screen._input(_key(KEY_E))
	watch_signals(screen)
	screen._close()
	assert_signal_emitted(screen, "closed")
	assert_true(FileAccess.file_exists(_profile_path))
	var saved: CharacterProfile = CharacterProfile.load_or_create(PROFILE_ID)
	assert_eq(saved.display_name, "Rook")
	assert_eq(saved.total_xp, profile.total_xp)
	assert_eq(saved.loadout[&"sidearm"].get("uid"), "sidearm")
	assert_eq(saved.stash[4], {})


func test_escape_and_controller_b_save_and_close() -> void:
	watch_signals(screen)
	screen._input(_key(KEY_ESCAPE))
	assert_signal_emitted(screen, "closed")
	assert_true(FileAccess.file_exists(_profile_path))
	screen.open(profile)
	var cancel: InputEventJoypadButton = InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	screen._input(cancel)
	assert_signal_emit_count(screen, "closed", 2)


func test_failed_save_keeps_screen_open_and_reports_failure() -> void:
	profile.id = &"test_character_screen_missing/profile"
	watch_signals(screen)
	screen._close()
	assert_signal_not_emitted(screen, "closed")
	assert_true(screen.visible)
	assert_string_contains((screen.get_node("%Status") as Label).text.to_lower(), "save")
	assert_eq((screen.get_node("%Back") as Button).text, "Close without saving")
	screen._close()
	assert_signal_emitted(screen, "closed", "A second Back always lets the player leave")


func test_columns_and_footer_fit_the_base_and_1440p_viewports() -> void:
	var viewport: SubViewport = SubViewport.new()
	add_child_autofree(viewport)
	var layout: CharacterScreen = SCREEN.instantiate() as CharacterScreen
	viewport.add_child(layout)
	layout.open(profile)
	for viewport_size: Vector2i in [Vector2i(1600, 900), Vector2i(2560, 1440)]:
		viewport.size = viewport_size
		await wait_process_frames(3)
		var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport_size))
		for path: String in [
			"Margin/Layout/Columns/Loadout",
			"Margin/Layout/Columns/Stash",
			"Margin/Layout/Columns/ItemTooltip",
			"Margin/Layout/Footer"
		]:
			var control: Control = layout.get_node(path) as Control
			assert_true(bounds.encloses(control.get_global_rect()), "%s fits at %s" % [path, viewport_size])


func _slot_button(slot: StringName) -> Button:
	for button: Button in screen.slots.buttons:
		if screen.slots.slot_of(button) == slot:
			return button
	return null


func _choose(name: String, index: int) -> void:
	var option: OptionButton = screen.get_node("%" + name) as OptionButton
	option.select(index)
	option.item_selected.emit(index)


func _stash_button(index: int) -> Button:
	for button: Button in screen.stash_buttons:
		if button.get_meta("stash_index", -1) == index:
			return button
	return null


func _item(base: String, uid: String, rarity: String, level: int) -> Dictionary:
	return {"v": 1, "uid": uid, "base": base, "rar": rarity, "ilvl": level, "aff": [], "imp": []}


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _remove_save() -> void:
	for path: String in [_profile_path, _profile_path + ".tmp", _profile_path + ".v0.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## Quick Pack inspection over the live HUD; mouse look stops while movement continues.
class_name PackOverlay
extends Control

const TOOLTIP: PackedScene = preload("res://systems/ui/item_tooltip.tscn")

var service: LootService
var count: Label
var panel: PanelContainer
var slots: Array[Button] = []
var tooltip: ItemTooltip
var guns: Label
var feed: Label
var _feed_left: float = 0.0
var _selected: int = 0
var _previous_items: int = 0
var _run_weapons: Dictionary[String, WeaponInstance] = {}


func _ready() -> void:
	theme = preload("res://systems/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	count = Label.new()
	count.position = Vector2(48, -190)
	count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	count.position = Vector2(48, size.y - 190)
	add_child(count)
	feed = Label.new()
	feed.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	feed.position = Vector2(size.x * 0.38, size.y - 150)
	add_child(feed)
	_build_panel()
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color("0b1014", 0.97)
	background.content_margin_left = 24
	background.content_margin_right = 24
	background.content_margin_top = 100
	background.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", background)
	resized.connect(_layout)
	_layout()


func setup(loot: LootService) -> void:
	if loot == null:
		return
	service = loot
	service.pack.changed.connect(_refresh)
	_refresh()


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.hide()
	add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = "Pack · 6 slots"
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	var hint: Label = Label.new()
	hint.text = "The match keeps running. You keep loot on death."
	box.add_child(hint)
	guns = Label.new()
	guns.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(guns)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	for index: int in Pack.CAPACITY:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(180, 90)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_select.bind(index))
		button.focus_entered.connect(_select.bind(index))
		grid.add_child(button)
		slots.append(button)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var actions: HBoxContainer = HBoxContainer.new()
	box.add_child(actions)
	var equip: Button = Button.new()
	equip.text = "E · Into hands"
	equip.pressed.connect(_equip)
	actions.add_child(equip)
	var discard: Button = Button.new()
	discard.text = "G · Drop"
	discard.pressed.connect(_drop)
	actions.add_child(discard)
	var close: Button = Button.new()
	close.text = "Tab · Close"
	close.pressed.connect(set_open.bind(false))
	actions.add_child(close)
	tooltip = TOOLTIP.instantiate() as ItemTooltip
	tooltip.hide()
	add_child(tooltip)


func _layout() -> void:
	count.position = Vector2(48, size.y - 190)
	feed.position = Vector2(size.x * 0.38, size.y - 150)
	panel.position = Vector2.ZERO
	panel.size = Vector2(size.x * 0.5, size.y)
	tooltip.position = Vector2(size.x * 0.5 + 16, size.y * 0.14)
	tooltip.size = Vector2(size.x * 0.45, 0)


func _refresh() -> void:
	var items: Array[Dictionary] = service.pack.items
	count.text = "Pack %d / 6 [Tab]" % items.size()
	if items.size() > _previous_items:
		var item: Dictionary = items.back()
		feed.text = "%s %s" % [String(item.get("rar", "common")).capitalize(), LootDrop.item_name(item)]
		feed.modulate = _colour(item)
		_feed_left = 4.0
	_previous_items = items.size()
	for index: int in slots.size():
		var item: Dictionary = items[index] if index < items.size() else {}
		var rarity: String = item.get("rar", "common")
		var rank: int = maxi(ItemRoller.RARITIES.find(StringName(rarity)), 0)
		slots[index].text = (
			(
				"%s\n%s %s · %d"
				% [LootDrop.item_name(item), ItemTooltip.SHAPES[rank], rarity.capitalize(), item.get("ilvl", 1)]
			)
			if not item.is_empty()
			else "Empty"
		)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("121a20", 0.94)
		style.set_border_width_all(1)
		style.border_color = _colour(item) if not item.is_empty() else Color("2c3b44")
		slots[index].add_theme_stylebox_override("normal", style)
		slots[index].add_theme_color_override("font_color", _colour(item))
	_select(mini(_selected, maxi(items.size() - 1, 0)))


static func _colour(item: Dictionary) -> Color:
	return (Content.get_item(&"loot", StringName(item.get("rar", "common"))) as RarityData).colour


func _select(index: int) -> void:
	_selected = index
	var items: Array[Dictionary] = service.pack.items
	tooltip.show_item(items[index] if index < items.size() else {})


func set_open(open: bool) -> void:
	panel.visible = open
	tooltip.visible = open
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	if open:
		Input.action_release(&"fire")
		Input.action_release(&"ads")
		var names: PackedStringArray = []
		for weapon: Weapon in service.player.weapons.weapons:
			names.append(weapon.data.display_name)
		guns.text = "In your hands\n" + " · ".join(names)
		slots[_selected].grab_focus()


func _input(event: InputEvent) -> void:
	if service == null or not is_instance_valid(service.player):
		return
	if panel.visible and event is InputEventMouseButton:
		Input.action_release(&"fire")
		Input.action_release(&"ads")
	if service.session.is_over or get_tree().paused:
		if panel.visible:
			set_open(false)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_key(event)
	elif panel.visible and event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func _key(event: InputEventKey) -> void:
	if event.physical_keycode == KEY_TAB:
		set_open(not panel.visible)
	elif not panel.visible:
		return
	elif event.is_action_pressed(&"pause"):
		set_open(false)
	elif event.physical_keycode == KEY_G:
		_drop()
	elif event.physical_keycode == KEY_E:
		_equip()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_feed_left = maxf(_feed_left - delta, 0.0)
	feed.modulate.a = minf(_feed_left, 1.0)
	if panel.visible and service and service.session.is_over:
		set_open(false)


func _drop() -> void:
	var item: Dictionary = service.pack.remove(_selected)
	if item.is_empty():
		return
	service._receive_drop(item, service.player.global_position - service.player.global_basis.z)


func _equip() -> void:
	var items: Array[Dictionary] = service.pack.items
	if _selected >= items.size() or service.player.is_downed or not service.player.is_alive():
		return
	var item: Dictionary = items[_selected]
	var base: StringName = StringName(item.get("base", ""))
	if not Content.ids(&"weapons").has(base):
		return
	for held: Weapon in service.player.weapons.weapons:
		if held.item and held.item.data.get("uid") == item.get("uid"):
			service.player.weapons.equip(service.player.weapons.weapons.find(held))
			return
	var uid: String = String(item["uid"])
	var previous: WeaponInstance = _run_weapons.get(uid)
	var instance: ItemInstance = ItemInstance.new(item)
	var weapon: Weapon = service.player.weapons.give(instance.weapon_data(Content.weapon(base), service.player.stats))
	if previous:
		weapon.instance.ammo_in_mag = mini(previous.ammo_in_mag, weapon.data.magazine_size)
		weapon.instance.ammo_reserve = mini(previous.ammo_reserve, weapon.data.max_reserve)
	_run_weapons[uid] = weapon.instance
	weapon.ammo_changed.emit(weapon.instance.ammo_in_mag, weapon.instance.ammo_reserve)
	weapon.item = instance
	weapon.hit_landed.connect(ItemLoadout._on_hit.bind(service.player, instance))

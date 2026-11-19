## Top of the Tab Pack: your character in its worn gear, gear slots on the left, guns in hand on the right.
class_name PackCharacter
extends HBoxContainer

signal slot_selected(item: Dictionary)

const GUN_BOXES: int = 2

var slot_buttons: Dictionary[StringName, Button] = {}
var gun_buttons: Array[Button] = []
var _service: LootService

@onready var rig: GearRig = %GearRig
@onready var viewport: SubViewport = %Viewport


func _ready() -> void:
	for slot: StringName in CharacterProfile.GEAR_SLOTS:
		var button: Button = _box()
		button.pressed.connect(_select_slot.bind(slot))
		button.focus_entered.connect(_select_slot.bind(slot))
		%Slots.add_child(button)
		slot_buttons[slot] = button
	for index: int in GUN_BOXES:
		var gun: Button = _box()
		gun.focus_mode = Control.FOCUS_NONE
		%Guns.add_child(gun)
		gun_buttons.append(gun)
	set_rendering(false)


func setup(service: LootService) -> void:
	_service = service


## The preview only draws while the Pack is open.
func set_rendering(enabled: bool) -> void:
	viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED)


func worn(slot: StringName) -> Dictionary:
	var profile: CharacterProfile = _service.session.profile if _service and _service.session else null
	return profile.loadout.get(String(slot), {}) if profile else {}


func refresh() -> void:
	if _service == null:
		return
	var loadout: Dictionary = {}
	for slot: StringName in slot_buttons:
		var item: Dictionary = worn(slot)
		loadout[String(slot)] = item
		_paint(slot_buttons[slot], item, String(slot).capitalize())
	rig.apply(LookBuilder.from_equipped(loadout))
	_refresh_guns()
	var profile: CharacterProfile = _service.session.profile
	%Level.text = "Level %d" % (profile.level if profile else 1)
	if is_instance_valid(_service.player):
		%Health.text = "Health %d" % roundi(_service.player.health.max_health)


func _refresh_guns() -> void:
	var weapons: Array[Weapon] = []
	if is_instance_valid(_service.player):
		weapons = _service.player.weapons.weapons
	for index: int in gun_buttons.size():
		var button: Button = gun_buttons[index]
		button.visible = index < weapons.size()
		if not button.visible:
			continue
		var weapon: Weapon = weapons[index]
		var item: Dictionary = weapon.item.data if weapon.item else {"rar": "common"}
		_paint(button, item, "Gun", weapon.data.display_name)


func _select_slot(slot: StringName) -> void:
	slot_selected.emit(worn(slot))


func _box() -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0, 64)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button


func _paint(button: Button, item: Dictionary, label: String, name_text: String = "") -> void:
	var empty: bool = item.is_empty()
	var rarity: String = item.get("rar", "common")
	var rank: int = maxi(ItemRoller.RARITIES.find(StringName(rarity)), 0)
	var shown: String = name_text if not name_text.is_empty() else LootDrop.item_name(item)
	button.text = "%s\n%s" % [label, "Empty" if empty else "%s %s" % [ItemTooltip.SHAPES[rank], shown]]
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("121a20", 0.94)
	style.set_border_width_all(1)
	style.border_color = Color("2c3b44") if empty else PackOverlay._colour(item)
	style.content_margin_left = 10.0
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("8fa3a8") if empty else PackOverlay._colour(item))

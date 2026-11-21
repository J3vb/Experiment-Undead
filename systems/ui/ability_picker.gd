## Field ability row under the Research tree (plans/field-abilities.md step 7, ui-hud.md): one
## button per ability in unlock order with its icon and name. Locked ones are dim with "Level N";
## the one the character brings is pressed. A click on an unlocked one saves it as the pick.
class_name AbilityPicker
extends HBoxContainer

const BUTTON_SIZE: Vector2 = Vector2(210, 56)
const ICON_WIDTH: int = 30

var profile: CharacterProfile
var buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	add_theme_constant_override(&"separation", 14)
	var title: Label = Label.new()
	title.text = "FIELD ABILITY"
	title.custom_minimum_size = Vector2(160, 0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", SkillTile.TEAL)
	add_child(title)
	for data: AbilityData in FieldAbility.all_by_unlock():
		var button: Button = Button.new()
		button.name = String(data.id)
		button.toggle_mode = true
		button.icon = data.icon
		button.custom_minimum_size = BUTTON_SIZE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override(&"icon_max_width", ICON_WIDTH)
		button.add_theme_constant_override(&"h_separation", 10)
		_style(button)
		button.tooltip_text = data.description
		button.pressed.connect(pick.bind(data.id))
		buttons[data.id] = button
		add_child(button)


func open(character: CharacterProfile) -> void:
	profile = character
	refresh()


## The ability this character brings into a run now.
func current() -> AbilityData:
	return FieldAbility.pick_for(profile.field_ability, profile.level) if profile else null


func refresh() -> void:
	var level: int = profile.level if profile else 1
	var brought: AbilityData = current()
	for data: AbilityData in FieldAbility.all_by_unlock():
		var button: Button = buttons[data.id]
		var locked: bool = data.unlock_level > level
		button.disabled = locked
		button.text = "%s\nLocked (level %d)" % [data.display_name, data.unlock_level] if locked else data.display_name
		button.set_pressed_no_signal(data == brought)


## Skill tile plates: teal edge open, green and glowing for the pick, grey when locked.
func _style(button: Button) -> void:
	button.add_theme_stylebox_override(&"normal", SkillTile._plate(SkillTile.TEAL.darkened(0.35), 2, false))
	button.add_theme_stylebox_override(&"hover", SkillTile._plate(SkillTile.TEAL.darkened(0.35), 2, false))
	button.add_theme_stylebox_override(&"disabled", SkillTile._plate(SkillTile.GREY, 2, false))
	button.add_theme_stylebox_override(&"pressed", SkillTile._plate(SkillTile.GREEN, 2, true))
	button.add_theme_stylebox_override(&"hover_pressed", SkillTile._plate(SkillTile.GREEN, 2, true))
	button.add_theme_stylebox_override(&"focus", SkillTile._plate(SkillTile.TEAL, 3, false, true))
	button.add_theme_color_override(&"font_disabled_color", SkillTile.GREY)
	button.add_theme_color_override(&"icon_disabled_color", SkillTile.GREY)


## Saves id as the pick. False for a locked or unknown ability.
func pick(id: StringName) -> bool:
	var data: AbilityData = Content.get_item(&"abilities", id) as AbilityData if Content.has(&"abilities", id) else null
	if profile == null or data == null or data.unlock_level > profile.level:
		refresh()
		return false
	profile.field_ability = String(id)
	profile.save()
	refresh()
	return true

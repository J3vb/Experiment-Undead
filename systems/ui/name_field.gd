## The character's name on the Character screen: typed here, cleaned and kept on the profile.
class_name NameField
extends LineEdit

var profile: CharacterProfile


func _ready() -> void:
	max_length = CharacterProfile.NAME_MAX
	text_submitted.connect(func(_text: String) -> void: release_focus())
	focus_exited.connect(apply)


func open(character: CharacterProfile) -> void:
	profile = character
	text = profile.display_name


## Cleans the typed text into the profile and shows the cleaned name.
func apply() -> void:
	if profile == null:
		return
	profile.display_name = CharacterProfile.clean_name(text)
	text = profile.display_name


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		release_focus()
		accept_event()

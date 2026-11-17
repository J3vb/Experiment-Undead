## One row on the settings screen: which page it sits on, the Settings key it edits and how to draw it.
class_name SettingData
extends Resource

## Settings page id: controls, aim, graphics, audio, accessibility or comfort.
@export var page: StringName = &""
@export var section: StringName = &""
@export var key: StringName = &""
@export var label: String = ""
## One line under the row that says what the option does.
@export var hint: String = ""
## toggle, slider or choice.
@export var kind: StringName = &"toggle"
@export var min_value: float = 0.0
@export var max_value: float = 1.0
@export var step: float = 0.01
## Shown value = saved value x display_scale; 100 shows a fraction as a percent.
@export var display_scale: float = 1.0
## Choice labels. The saved value is the index unless option_values is set.
@export var options: PackedStringArray = []
## Saved value for each option, converted to the type of the key's default (int or String).
@export var option_values: PackedStringArray = []
## Options that can be shown but not picked, like the preset's Custom.
@export var locked_options: PackedInt32Array = []
@export var order: int = 0
## Applies when a mouse drag ends, for options that resize the screen under the cursor (text size).
@export var apply_on_release: bool = false
## Display mode and resolution ask "Keep these settings?" after a change.
@export var needs_confirm: bool = false

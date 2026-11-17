## Hold or toggle for aim, sprint and crouch: toggles flip on press, holds follow the key, both clear when input stops.
extends GutTest

const PATH: String = "user://test_local_input.cfg"

var _local: LocalInput
var _old_path: String
var _old_values: Dictionary


func before_each() -> void:
	_old_path = Settings.config_path
	_old_values = Settings._values.duplicate(true)
	Settings.config_path = PATH
	Settings.reset_to_defaults()
	_local = LocalInput.new()
	add_child_autofree(_local)


func after_each() -> void:
	for action: StringName in [&"ads", &"sprint", &"crouch"]:
		Input.action_release(action)
	Settings._values = _old_values
	Settings._apply_all()
	Settings.config_path = _old_path
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.action_press(action)
	_local._unhandled_input(event)


func test_toggle_aim_stays_aimed_after_release_and_drops_on_second_press() -> void:
	Settings.set_value(&"accessibility", &"toggle_ads", true)
	_press(&"ads")
	Input.action_release(&"ads")
	assert_true(_local.sample(1).has(InputFrame.ADS), "still aiming after release")
	assert_true(_local.sample(2).has(InputFrame.ADS))
	_press(&"ads")
	Input.action_release(&"ads")
	assert_false(_local.sample(3).has(InputFrame.ADS))


func test_hold_aim_is_unchanged() -> void:
	_press(&"ads")
	assert_true(_local.sample(1).has(InputFrame.ADS))
	Input.action_release(&"ads")
	assert_false(_local.sample(2).has(InputFrame.ADS), "hold mode stops on release")


func test_toggle_sprint_and_hold_crouch() -> void:
	Settings.set_value(&"accessibility", &"toggle_sprint", true)
	Settings.set_value(&"accessibility", &"toggle_crouch", false)
	_press(&"sprint")
	Input.action_release(&"sprint")
	assert_true(_local.sample(1).has(InputFrame.SPRINT))
	_press(&"crouch")
	assert_true(_local.sample(2).has(InputFrame.CROUCH))
	Input.action_release(&"crouch")
	assert_false(_local.sample(3).has(InputFrame.CROUCH), "hold crouch stops on release")


func test_crouch_toggles_by_default() -> void:
	_press(&"crouch")
	Input.action_release(&"crouch")
	assert_true(_local.sample(1).has(InputFrame.CROUCH))
	_press(&"jump")
	Input.action_release(&"jump")
	assert_false(_local.sample(2).has(InputFrame.CROUCH), "jump stands up")


func test_toggles_clear_when_input_is_disabled() -> void:
	Settings.set_value(&"accessibility", &"toggle_ads", true)
	_press(&"ads")
	Input.action_release(&"ads")
	_local.enabled = false
	_local.sample(1)
	_local.enabled = true
	assert_false(_local.sample(2).has(InputFrame.ADS), "death or match end drops a toggled aim")

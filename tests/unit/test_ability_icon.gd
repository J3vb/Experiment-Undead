## AbilityIcon shows the local player's field ability, its cooldown sweep, the seconds left and its key.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var icon: AbilityIcon
var player: Player


func before_each() -> void:
	icon = AbilityIcon.new()
	add_child_autofree(icon)
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.abilities.set_physics_process(false)
	Events.player_spawned.emit(player)


func _give_pulse() -> AbilityData:
	player.abilities.ability = FieldAbility.pick_for_level(3)
	return player.abilities.ability


func test_hidden_below_the_first_unlock() -> void:
	player.abilities.ability = FieldAbility.pick_for_level(2)
	icon.refresh(0.0)
	assert_false(icon.visible, "level 2 has no field ability")
	_give_pulse()
	icon.refresh(0.0)
	assert_true(icon.visible)


func test_sweep_follows_the_cooldown() -> void:
	var data: AbilityData = _give_pulse()
	player.abilities.cooldown_left = data.cooldown * 0.5
	icon.refresh(0.0)
	assert_almost_eq(icon.cooldown_share, 0.5, 0.01)
	assert_false(icon.is_ready())
	assert_eq(icon.seconds_left, 0, "no seconds above 10")
	player.abilities.cooldown_left = 3.2
	icon.refresh(0.0)
	assert_eq(icon.seconds_left, 4, "seconds round up under 10")


func test_ready_flash_when_the_cooldown_ends() -> void:
	_give_pulse()
	player.abilities.cooldown_left = 0.2
	icon.refresh(0.0)
	assert_eq(icon.flash_left, 0.0)
	player.abilities.cooldown_left = 0.0
	icon.refresh(0.0)
	assert_true(icon.is_ready())
	assert_eq(icon.seconds_left, 0)
	assert_almost_eq(icon.flash_left, AbilityIcon.FLASH_TIME, 0.001, "brass flash starts")
	icon.refresh(AbilityIcon.FLASH_TIME)
	assert_eq(icon.flash_left, 0.0, "and ends")


func test_other_players_are_ignored() -> void:
	var other: Player = PLAYER.instantiate() as Player
	other.set_multiplayer_authority(7)
	add_child_autofree(other)
	Events.player_spawned.emit(other)
	assert_eq(icon.player, player)


func test_key_label_follows_rebinding() -> void:
	var old_path: String = Settings.config_path
	var old_values: Dictionary = Settings._values.duplicate(true)
	Settings.config_path = "user://test_ability_icon_bindings.cfg"
	assert_eq(icon.key_label, "X")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_G
	Settings.swap_binding(&"field_ability", 0, key)
	assert_eq(icon.key_label, "G")
	Settings.reset_binding(&"field_ability")
	assert_eq(icon.key_label, "X")
	Settings._values = old_values
	Settings._apply_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.config_path))
	Settings.config_path = old_path


func test_draws_without_errors() -> void:
	_give_pulse()
	player.abilities.cooldown_left = 5.0
	icon.refresh(0.0)
	icon.queue_redraw()
	await get_tree().process_frame
	assert_true(icon.visible)

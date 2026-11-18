## Downed, revived and death screen for the local player, the world-sound fade,
## and the camera drop that goes with them.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const SCREEN: PackedScene = preload("res://systems/feel/down_screen.tscn")
const DT: float = 1.0 / 60.0

var player: Player
var screen: DownScreen
var _saved_flash: Variant


func before_each() -> void:
	_saved_flash = Settings.get_value(&"comfort", &"flash_reduction")
	Settings._values[&"comfort"][&"flash_reduction"] = false
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.session = autofree(GameSession.new()) as GameSession
	screen = SCREEN.instantiate() as DownScreen
	add_child_autofree(screen)
	screen.set_physics_process(false)
	screen.set_player(player)


func after_each() -> void:
	Settings._values[&"comfort"][&"flash_reduction"] = _saved_flash


func _settle() -> void:
	screen._process(DT)
	if screen._tween and screen._tween.is_valid():
		screen._tween.custom_step(2.0)


func _shader(key: StringName) -> float:
	return float((screen.material as ShaderMaterial).get_shader_parameter(key))


func _feel_ticks(seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		player.camera_rig.update_feel(DT, player.is_downed, false, 0.0, player.camera_rig.base_fov, player.walk_speed)


func test_downed_desaturates_and_shows_vignette() -> void:
	player.is_downed = true
	_settle()
	assert_eq(screen.state, DownScreen.State.DOWN)
	assert_almost_eq(_shader(&"saturation"), 0.2, 0.001)
	assert_almost_eq(_shader(&"vignette"), 0.5, 0.001)
	assert_true(screen.visible, "overlay shows while down")


func test_death_fades_to_black_and_drops_only_world_sound() -> void:
	player.is_dead = true
	_settle()
	assert_eq(screen.state, DownScreen.State.DEAD)
	assert_almost_eq(_shader(&"black"), 1.0, 0.001)
	assert_almost_eq(screen.world_db(), DownScreen.QUIET_DB, 0.01, "world sound dropped")
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"UI")), &"Master", "UI skips the faded SFX bus")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Music")), &"Master", "music is not faded")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Enemies")), &"SFX", "zombies are faded")
	var door: Node = (load("res://systems/interactables/door.tscn") as PackedScene).instantiate()
	var players: Array[Node] = door.find_children("*", "AudioStreamPlayer3D")
	players.append_array(door.find_children("*", "AudioStreamPlayer"))
	for sound: Node in players:
		assert_eq(AudioServer.get_bus_index(sound.get(&"bus")), sfx, "door sounds go through the faded SFX bus")
	door.free()


func test_squad_wipe_fades_but_exfil_does_not() -> void:
	player.session.is_over = true
	_settle()
	assert_eq(screen.state, DownScreen.State.UP, "match over while standing (exfil) never fades")
	player.is_downed = true
	_settle()
	assert_eq(screen.state, DownScreen.State.DEAD, "match over while downed is a squad wipe")
	assert_almost_eq(_shader(&"black"), 1.0, 0.001)


func test_respawn_and_exit_restore_world_sound() -> void:
	player.is_dead = true
	_settle()
	player.is_dead = false
	_settle()
	assert_eq(screen.state, DownScreen.State.UP)
	assert_eq(screen.world_db(), 0.0, "respawn restores world sound")
	assert_almost_eq(_shader(&"black"), 0.0, 0.001)
	player.is_dead = true
	_settle()
	remove_child(screen)
	assert_eq(screen.world_db(), 0.0, "leaving the tree restores world sound")
	add_child(screen)


func test_spectating_brings_world_sound_back() -> void:
	player.is_dead = true
	_settle()
	screen._back_to_spectate()
	screen._tween.custom_step(2.0)
	assert_eq(screen.world_db(), 0.0, "spectators hear the fight")
	assert_almost_eq(_shader(&"black"), 0.0, 0.001, "fades back in on the spectate camera")


func test_revive_flash_and_flash_reduction() -> void:
	player.is_downed = true
	_settle()
	player.is_downed = false
	screen._process(DT)
	assert_almost_eq(_shader(&"flash"), 0.08, 0.001, "revive starts with an 8% flash")
	screen._tween.custom_step(2.0)
	assert_almost_eq(_shader(&"flash"), 0.0, 0.001)
	assert_false(screen.visible, "overlay hides when nothing shows")
	Settings._values[&"comfort"][&"flash_reduction"] = true
	player.is_downed = true
	_settle()
	player.is_downed = false
	screen._process(DT)
	assert_eq(_shader(&"flash"), 0.0, "flash reduction skips it")


func test_no_local_player_does_nothing() -> void:
	var lone: DownScreen = SCREEN.instantiate() as DownScreen
	add_child_autofree(lone)
	player.remove_from_group(&"players")
	lone._process(DT)
	assert_eq(lone.state, DownScreen.State.UP)
	assert_eq(lone.world_db(), 0.0)


func test_downed_and_dead_drop_from_standing_and_revive_restores() -> void:
	player.is_downed = true
	player.is_crouching = true
	_feel_ticks(0.3)
	assert_almost_eq(player.camera_rig.position.y, 0.7, 0.05, "0.9 m below standing, even while crouched")
	player.is_downed = false
	player.is_crouching = false
	_feel_ticks(1.0)
	assert_almost_eq(player.camera_rig.position.y, player.camera_rig.stand_height, 0.01)
	player.is_dead = true
	_feel_ticks(0.5)
	assert_almost_eq(player.camera_rig.position.y, 0.7, 0.05, "solo death drops the same 0.9 m")


func test_solo_death_and_second_wind_use_tilt_down() -> void:
	player.take_damage(DamageInfo.create(10000.0, null))
	assert_true(player.is_dead)
	for i: int in 30:
		player.camera_rig._tilt.custom_step(DT)
	assert_almost_eq(player.camera_rig.rotation.z, deg_to_rad(6.0), 0.001, "solo death rolls 6°")
	assert_almost_eq(
		player.camera_rig.position.y,
		player.camera_rig.stand_height,
		0.001,
		"no tween moves the rig; update_feel drops it"
	)


func _sting() -> AudioStreamPlayer:
	return screen.get_node(^"Sting") as AudioStreamPlayer


func test_each_state_change_plays_its_sound_once_on_the_ui_bus() -> void:
	assert_eq(_sting().bus, &"UI", "stings skip the faded SFX bus")
	player.is_downed = true
	screen._process(DT)
	assert_eq(_sting().stream, screen.downed_sound)
	assert_true(_sting().playing)
	_sting().stop()
	screen._process(DT)
	assert_false(_sting().playing, "staying down does not replay")
	player.is_downed = false
	screen._process(DT)
	assert_eq(_sting().stream, screen.revived_sound)
	player.is_dead = true
	screen._process(DT)
	assert_eq(_sting().stream, screen.bled_out_sound)
	_sting().stop()
	player.is_dead = false
	screen._process(DT)
	assert_false(_sting().playing, "respawn after death is silent")


func test_remote_player_state_change_plays_nothing() -> void:
	player.set_multiplayer_authority(2)
	player.is_downed = true
	screen._process(DT)
	assert_false(_sting().playing)
	assert_null(_sting().stream)

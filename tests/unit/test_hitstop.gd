## Kill hitstop is local and visual: it freezes camera feel and the gun's look,
## never the simulation, never stacks and fires at most four times a second.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const DT: float = 1.0 / 60.0

var player: Player
var rig: PlayerCamera
var _saved: Variant


func before_each() -> void:
	_saved = Settings.get_value(&"comfort", &"shake_own_gun")
	Settings._values[&"comfort"][&"shake_own_gun"] = 1.0
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.session = autofree(GameSession.new()) as GameSession
	rig = player.camera_rig


func after_each() -> void:
	Settings._values[&"comfort"][&"shake_own_gun"] = _saved


func _give(id: StringName) -> Weapon:
	var weapon: Weapon = player.weapons.give(Content.weapon(id))
	player.weapons.equip(player.weapons.weapons.find(weapon))
	return weapon


func _step(seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		rig.update_feel(DT, false, false, 0.0, rig.base_fov, player.walk_speed)
		player.weapons._process(DT)


func test_headshot_kill_holds_25_ms() -> void:
	var weapon: Weapon = _give(&"rifle_ar")
	Events.hit_confirmed.emit(player, true, true)
	assert_true(rig.is_holding(), "camera holds")
	assert_true(player.weapons.is_holding(), "gun holds")
	assert_false(weapon.is_processing(), "gun look frozen")
	_step(0.02)
	assert_true(rig.is_holding(), "still holding at 20 ms")
	_step(0.02)
	assert_false(rig.is_holding(), "done by 40 ms")
	assert_true(weapon.is_processing(), "gun look resumes")


func test_shotgun_kill_holds_35_ms_and_rifle_body_kill_none() -> void:
	_give(&"rifle_ar")
	Events.hit_confirmed.emit(player, true, false)
	assert_false(rig.is_holding(), "normal kills have no hitstop")
	_give(&"brenner_trench")
	Events.hit_confirmed.emit(player, true, false)
	_step(0.03)
	assert_true(rig.is_holding(), "shotgun kill still holding at 30 ms")


func test_shorter_hitstop_never_cuts_a_longer_one() -> void:
	_give(&"rifle_ar")
	rig.hitstop(0.08)
	_step(0.03)
	rig.hitstop(0.025)
	_step(0.03)
	assert_true(rig.is_holding(), "the 80 ms hold is still running")


func test_fifth_hitstop_in_a_second_is_skipped() -> void:
	_give(&"rifle_ar")
	for i: int in 4:
		assert_true(rig.hitstop(0.001), "hitstop %d allowed" % i)
		_step(DT)
	assert_false(rig.hitstop(0.025), "fifth inside one second is skipped")
	_step(1.0)
	assert_true(rig.hitstop(0.025), "allowed again a second later")


func test_gun_still_fires_during_a_hold() -> void:
	var weapon: Weapon = _give(&"rifle_ar")
	player.weapons._swap_left = 0.0
	rig.hitstop(0.08)
	var before: int = weapon.instance.ammo_in_mag
	player.weapons.set_trigger(true)
	player.weapons.tick(DT)
	assert_lt(weapon.instance.ammo_in_mag, before, "the physics tick still shoots")


func test_headshot_kill_zooms_in() -> void:
	_give(&"rifle_ar")
	Events.hit_confirmed.emit(player, true, true)
	_step(0.05)
	assert_lt(rig.camera.fov, rig.base_fov, "FOV narrows on a headshot kill")


func test_comfort_zero_skips_hitstop_and_other_players() -> void:
	_give(&"rifle_ar")
	var other: Player = PLAYER.instantiate() as Player
	add_child_autofree(other)
	Events.hit_confirmed.emit(other, true, true)
	assert_false(rig.is_holding(), "another player's kill does nothing here")
	Settings._values[&"comfort"][&"shake_own_gun"] = 0.0
	Events.hit_confirmed.emit(player, true, true)
	assert_false(rig.is_holding(), "slider at 0 turns hitstop off")

## Cosmetic camera feel: trauma, view kick and FOV punch follow the game-feel doc
## and the comfort sliders, and never move where bullets go.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const SHOTGUN: FeelData = preload("res://content/feel/class_shotgun.tres")
const DT: float = 1.0 / 60.0

var player: Player
var rig: PlayerCamera
var _saved: Dictionary = {}


func before_each() -> void:
	for key: StringName in [&"shake_own_gun", &"shake_hits"]:
		_saved[key] = Settings.get_value(&"comfort", key)
		Settings._values[&"comfort"][key] = 1.0
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.session = autofree(GameSession.new()) as GameSession
	rig = player.camera_rig


func after_each() -> void:
	for key: StringName in _saved:
		Settings._values[&"comfort"][key] = _saved[key]


func _step(seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		rig.update_feel(DT, false, false, 0.0, rig.base_fov, player.walk_speed)


func test_trauma_decays_at_rules_rate_and_caps_at_one() -> void:
	rig.add_trauma(0.8, false)
	rig.add_trauma(0.8, false)
	assert_eq(rig.get_trauma(), 1.0, "trauma caps at 1")
	_step(0.5)
	assert_almost_eq(rig.get_trauma(), 1.0 - rig.rules.trauma_decay * 0.5, 0.03, "decays 1.6 per second")


func test_firing_alone_caps_trauma() -> void:
	for i: int in 10:
		rig.kick_view(SHOTGUN)
	assert_almost_eq(rig.get_trauma(), rig.rules.fire_trauma_cap, 0.001, "own gun stops at 0.35")
	rig.add_trauma(0.3, false)
	assert_gt(rig.get_trauma(), rig.rules.fire_trauma_cap, "hits still add on top")


func test_shake_rotates_only_the_camera_not_the_aim() -> void:
	var aim_before: Basis = PlayerCamera.aim_of(rig.camera)
	rig.kick_view(SHOTGUN)
	rig.add_trauma(1.0, false)
	_step(DT * 3.0)
	assert_ne(rig.camera.rotation, Vector3.ZERO, "camera moves")
	assert_true(PlayerCamera.aim_of(rig.camera).is_equal_approx(aim_before), "aim basis unchanged by feel")


func test_trace_basis_identical_with_shake_off_and_on() -> void:
	var weapon: Weapon = player.weapons.give(Content.weapon(&"rifle_ar"))
	assert_not_null(weapon)
	Settings._values[&"comfort"][&"shake_hits"] = 0.0
	rig.add_trauma(1.0, false)
	_step(DT * 2.0)
	var off: Basis = PlayerCamera.aim_of(weapon.camera)
	Settings._values[&"comfort"][&"shake_hits"] = 1.0
	rig.add_trauma(1.0, false)
	_step(DT * 2.0)
	assert_true(PlayerCamera.aim_of(weapon.camera).is_equal_approx(off), "same bullet basis at 0% and 100%")


func test_comfort_zero_removes_all_motion() -> void:
	Settings._values[&"comfort"][&"shake_own_gun"] = 0.0
	Settings._values[&"comfort"][&"shake_hits"] = 0.0
	rig.kick_view(SHOTGUN)
	rig.add_trauma(1.0, false)
	_step(DT * 3.0)
	assert_eq(rig.get_trauma(), 0.0, "no trauma")
	assert_true(rig.camera.rotation.is_zero_approx(), "camera still")
	assert_almost_eq(rig.camera.fov, rig.base_fov, 0.01, "no FOV punch")


func test_fov_punch_rises_and_returns() -> void:
	rig.punch_fov(2.0, 0.11)
	_step(0.05)
	assert_gt(rig.camera.fov, rig.base_fov + 0.5, "FOV widened")
	_step(0.2)
	assert_almost_eq(rig.camera.fov, rig.base_fov, 0.01, "back to base")


func test_view_kick_returns() -> void:
	rig.kick_view(SHOTGUN)
	_step(DT)
	assert_gt(rig.camera.rotation.x, 0.0, "camera pitched up")
	_step(0.5)
	assert_almost_eq(rig.camera.rotation.x, 0.0, 0.002, "kick returned")


func test_ads_halves_trauma() -> void:
	var weapon: Weapon = player.weapons.give(Content.weapon(&"rifle_ar"))
	weapon.ads_progress = 1.0
	rig.add_trauma(0.4, false)
	assert_almost_eq(rig.get_trauma(), 0.2, 0.001, "ADS halves incoming trauma")


func test_weapon_fired_from_another_player_is_ignored() -> void:
	var other: Player = PLAYER.instantiate() as Player
	add_child_autofree(other)
	other.set_physics_process(false)
	var weapon: Weapon = other.weapons.give(Content.weapon(&"brenner_trench"))
	Events.weapon_fired.emit(other, weapon)
	assert_eq(rig.get_trauma(), 0.0, "only the shooter's own camera reacts")
	assert_gt(other.camera_rig.get_trauma(), 0.0, "the shooter's camera kicks")


func test_player_damage_adds_hit_trauma() -> void:
	player.take_damage(DamageInfo.create(1.0, null))
	assert_almost_eq(rig.get_trauma(), rig.rules.hit_trauma, 0.001)

## Switching guns takes 0.4 s (Quickhands 40% less), 1/2/3 pick a slot and
## sprinting cancels a reload (docs/plans/core-loop-gaps.md, step 3).
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const PISTOL: WeaponData = preload("res://content/weapons/pistol_service.tres")
const RIFLE: WeaponData = preload("res://content/weapons/rifle_ar.tres")
const QUICKHANDS: SerumData = preload("res://content/serums/quickhands.tres")

var player: Player


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.weapons.give(PISTOL)
	player.weapons.give(RIFLE)
	player.weapons.tick(1.0)


func _tick(seconds: float) -> void:
	for i: int in roundi(seconds * 100.0):
		player.weapons.tick(0.01)


func _frame(buttons: int) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.buttons = buttons
	return frame


func test_switched_gun_cannot_fire_or_aim_for_swap_time() -> void:
	player.weapons.equip(0)
	assert_true(player.weapons.is_swapping())
	player.weapons.set_trigger(true)
	player.weapons.set_state(true, false, 0.0)
	assert_false(player.weapons.current.trigger_held, "trigger blocked while raising")
	assert_false(player.weapons.current.aiming, "no ADS while raising")
	_tick(0.39)
	assert_true(player.weapons.is_swapping(), "still raising at 0.39 s")
	_tick(0.02)
	assert_false(player.weapons.is_swapping(), "ready after 0.4 s")
	player.weapons.set_trigger(true)
	assert_true(player.weapons.current.trigger_held)


func test_quickhands_swaps_40_percent_faster() -> void:
	player.serums.append(QUICKHANDS)
	player.weapons.equip(0)
	_tick(0.23)
	assert_true(player.weapons.is_swapping())
	_tick(0.02)
	assert_false(player.weapons.is_swapping(), "0.24 s with Quickhands")


func test_equipping_the_gun_in_hand_is_free() -> void:
	player.weapons.equip(1)
	assert_false(player.weapons.is_swapping())


func test_slot_keys_pick_the_slot() -> void:
	player.weapons.switch_from(_frame(InputFrame.SLOT_1))
	assert_eq(player.weapons.current.data, PISTOL)
	player.weapons.switch_from(_frame(InputFrame.SLOT_2))
	assert_eq(player.weapons.current.data, RIFLE)
	player.weapons.switch_from(_frame(InputFrame.SLOT_3))
	assert_eq(player.weapons.current.data, RIFLE, "no third gun without Mule")


func test_sprinting_cancels_a_reload_and_keeps_the_magazine() -> void:
	var gun: Weapon = player.weapons.current
	gun.instance.ammo_in_mag = 5
	assert_true(gun.start_reload())
	gun.tick(0.5)
	player.weapons.set_state(false, true, 1.0)
	assert_false(gun.is_reloading(), "sprint cancelled the reload")
	assert_eq(gun.instance.ammo_in_mag, 5, "magazine unchanged")
	gun.tick(5.0)
	assert_eq(gun.instance.ammo_in_mag, 5, "no late refill")


func test_walking_does_not_cancel_a_reload() -> void:
	var gun: Weapon = player.weapons.current
	gun.instance.ammo_in_mag = 5
	gun.start_reload()
	player.weapons.set_state(false, false, 1.0)
	assert_true(gun.is_reloading())


func test_no_fire_path_shoots_while_raising() -> void:
	player.weapons.equip(0)
	var gun: Weapon = player.weapons.current
	watch_signals(gun)
	gun.trigger_held = true
	gun._buffered = Weapon.BUFFER_TIME
	_tick(0.3)
	assert_signal_not_emitted(gun, "fired", "buffered or held shots wait for the raise")
	_tick(0.15)
	assert_signal_emitted(gun, "fired")


func test_a_gun_put_away_while_aiming_comes_back_unaimed() -> void:
	var rifle: Weapon = player.weapons.current
	rifle.ads_progress = 1.0
	player.weapons.equip(0)
	_tick(0.5)
	player.weapons.equip(1)
	assert_eq(rifle.ads_progress, 0.0, "no aimed zoom or slow walk during the raise")

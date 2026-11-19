## RoundReload inserts real rounds, retains partial loads on firing and leaves magazine guns unchanged.
extends GutTest

const WEAPON: PackedScene = preload("res://systems/weapons/weapon.tscn")


func _gun(in_mag: int = 2, reserve: int = 8) -> Weapon:
	var data: WeaponData = WeaponData.new()
	data.fire_mode = WeaponData.FireMode.SEMI
	data.magazine_size = 8
	data.reload_per_round = true
	data.per_round_time = 0.5
	data.empty_reload_time = 0.5
	data.hip_spread = 0.0
	data.ads_spread = 0.0
	data.spread_per_shot = 0.0
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	var weapon: Weapon = WEAPON.instantiate() as Weapon
	weapon.setup(WeaponInstance.new(data), null, camera)
	camera.add_child(weapon)
	weapon.set_active(true)
	weapon.instance.ammo_in_mag = in_mag
	weapon.instance.ammo_reserve = reserve
	return weapon


func test_loads_one_round_per_interval_and_reports_each_insert() -> void:
	var weapon: Weapon = _gun()
	watch_signals(weapon)
	assert_true(weapon.start_reload())
	weapon.tick(0.49)
	assert_eq(weapon.instance.ammo_in_mag, 2)
	assert_eq(weapon.instance.ammo_reserve, 8)
	assert_signal_not_emitted(weapon, "ammo_changed")
	weapon.tick(0.02)
	assert_eq(weapon.instance.ammo_in_mag, 3)
	assert_eq(weapon.instance.ammo_reserve, 7)
	assert_true(weapon.is_reloading())
	weapon.tick(0.5)
	assert_eq(weapon.instance.ammo_in_mag, 4)
	assert_eq(weapon.instance.ammo_reserve, 6)
	assert_signal_emit_count(weapon, "ammo_changed", 2)
	assert_signal_emitted_with_parameters(weapon, "reload_started", [0.5])


func test_long_tick_carries_time_across_rounds_without_refilling_whole_tube() -> void:
	var weapon: Weapon = _gun(0)
	weapon.start_reload()
	weapon.tick(1.26)
	assert_eq(weapon.instance.ammo_in_mag, 2)
	assert_eq(weapon.instance.ammo_reserve, 6)
	weapon.tick(0.25)
	assert_eq(weapon.instance.ammo_in_mag, 3, "the unfinished interval survives the previous tick")


func test_full_tube_ends_reload_without_spending_extra_reserve() -> void:
	var weapon: Weapon = _gun(6)
	weapon.start_reload()
	weapon.tick(5.0)
	assert_eq(weapon.instance.ammo_in_mag, 8)
	assert_eq(weapon.instance.ammo_reserve, 6)
	assert_false(weapon.is_reloading())


func test_empty_reserve_ends_reload_at_last_insert() -> void:
	var weapon: Weapon = _gun(0, 2)
	weapon.start_reload()
	weapon.tick(5.0)
	assert_eq(weapon.instance.ammo_in_mag, 2)
	assert_eq(weapon.instance.ammo_reserve, 0)
	assert_false(weapon.is_reloading())
	assert_false(weapon.start_reload())
	weapon.tick(5.0)
	assert_eq(weapon.instance.ammo_in_mag, 2, "no more rounds appear after reserve runs out")


func test_firing_cancels_reload_and_keeps_loaded_rounds() -> void:
	var weapon: Weapon = _gun()
	weapon.start_reload()
	weapon.tick(0.51)
	watch_signals(weapon)
	weapon.trigger_held = true
	weapon.tick(0.01)
	assert_signal_emit_count(weapon, "fired", 1)
	assert_false(weapon.is_reloading())
	assert_eq(weapon.instance.ammo_in_mag, 2, "three rounds were loaded before the shot")
	assert_eq(weapon.instance.ammo_reserve, 7, "cancel does not consume another round")
	weapon.trigger_held = false
	weapon.tick(5.0)
	assert_eq(weapon.instance.ammo_in_mag, 2, "the cancelled timer cannot insert another round")


func test_empty_tube_waits_for_first_round_before_firing() -> void:
	var weapon: Weapon = _gun(0, 2)
	weapon.start_reload()
	watch_signals(weapon)
	weapon.trigger_held = true
	weapon.tick(0.1)
	assert_signal_not_emitted(weapon, "fired")
	assert_true(weapon.is_reloading())
	weapon.trigger_held = false
	weapon.tick(0.41)
	weapon.trigger_held = true
	weapon.tick(0.01)
	assert_signal_emit_count(weapon, "fired", 1)
	assert_eq(weapon.instance.ammo_in_mag, 0)
	assert_eq(weapon.instance.ammo_reserve, 1)
	assert_true(weapon.is_reloading(), "emptying the tube starts the usual automatic reload")


func test_sprinting_blocks_fire_without_cancelling_reload() -> void:
	var weapon: Weapon = _gun()
	weapon.start_reload()
	watch_signals(weapon)
	weapon.sprinting = true
	weapon.trigger_held = true
	weapon.tick(0.1)
	assert_signal_not_emitted(weapon, "fired")
	assert_true(weapon.is_reloading())
	weapon.tick(0.41)
	assert_eq(weapon.instance.ammo_in_mag, 3, "loading continues while a shot is blocked")


func test_shot_cooldown_does_not_cancel_or_restart_loading() -> void:
	var weapon: Weapon = _gun()
	weapon.start_reload()
	weapon._shot_timer = 0.3
	watch_signals(weapon)
	weapon.trigger_held = true
	weapon.tick(0.1)
	assert_signal_not_emitted(weapon, "fired")
	assert_true(weapon.is_reloading())
	assert_almost_eq(weapon._reload_timer, 0.4, 0.001)


func test_reload_stat_scales_each_round_interval() -> void:
	var weapon: Weapon = _gun()
	var player: Player = autofree(Player.new()) as Player
	var serum: SerumData = SerumData.new()
	serum.multipliers = {&"reload_time": 0.5}
	player.serums.append(serum)
	weapon.shooter = player
	assert_almost_eq(RoundReload.duration(weapon), 0.25, 0.001)
	weapon.start_reload()
	weapon.tick(0.26)
	assert_eq(weapon.instance.ammo_in_mag, 3)
	weapon.tick(0.25)
	assert_eq(weapon.instance.ammo_in_mag, 4)


func test_existing_magazine_gun_defaults_keep_full_reload_and_cannot_cancel() -> void:
	var weapon: Weapon = _gun()
	weapon.data.reload_per_round = false
	weapon.data.reload_time = 1.0
	weapon.start_reload()
	watch_signals(weapon)
	weapon.trigger_held = true
	weapon.tick(0.51)
	assert_eq(weapon.instance.ammo_in_mag, 2)
	assert_true(weapon.is_reloading())
	assert_signal_not_emitted(weapon, "fired")
	weapon.trigger_held = false
	weapon.tick(0.5)
	assert_eq(weapon.instance.ammo_in_mag, 8)
	assert_eq(weapon.instance.ammo_reserve, 2)
	assert_false(weapon.is_reloading())
	assert_false(WeaponData.new().reload_per_round)


func test_brenner_loads_shell_by_shell_with_its_reforged_copy() -> void:
	var brenner: WeaponData = Content.weapon(&"brenner_trench")
	assert_true(brenner.reload_per_round)
	assert_true(brenner.upgraded.reload_per_round)


func test_first_round_from_empty_also_racks_then_each_shell_takes_its_interval() -> void:
	var weapon: Weapon = _gun(0, 36)
	weapon.data.magazine_size = 6
	weapon.data.empty_reload_time = 1.1
	assert_true(weapon.start_reload())
	weapon.tick(1.09)
	assert_eq(weapon.instance.ammo_in_mag, 0, "first shell waits for the rack")
	weapon.tick(0.02)
	assert_eq(weapon.instance.ammo_in_mag, 1)
	weapon.tick(2.48)
	assert_eq(weapon.instance.ammo_in_mag, 5)
	weapon.tick(0.02)
	assert_eq(weapon.instance.ammo_in_mag, 6, "full from empty in 1.1 + 5 x 0.5 = 3.6 s")
	assert_false(weapon.is_reloading())


func test_top_up_skips_the_rack() -> void:
	var weapon: Weapon = _gun(4, 36)
	weapon.data.magazine_size = 6
	weapon.data.empty_reload_time = 1.1
	assert_true(weapon.start_reload())
	weapon.tick(0.99)
	assert_eq(weapon.instance.ammo_in_mag, 5)
	weapon.tick(0.02)
	assert_eq(weapon.instance.ammo_in_mag, 6, "two shells in 1.0 s")
	assert_false(weapon.is_reloading())


func test_cycle_progress_follows_the_round_now_loading() -> void:
	var weapon: Weapon = _gun(0, 36)
	weapon.data.empty_reload_time = 1.0
	assert_true(weapon.start_reload())
	weapon.tick(0.25)
	assert_almost_eq(RoundReload.cycle_t(weapon), 0.25, 0.001)
	weapon.tick(1.0)
	assert_almost_eq(RoundReload.cycle_t(weapon), 0.5, 0.001, "second shell, half way")

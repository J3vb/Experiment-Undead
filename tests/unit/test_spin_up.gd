## Spin-up scales intervals, follows held-trigger time and resets across weapon use.
extends GutTest

const BASE_INTERVAL: float = 60.0 / 800.0
const WEAPON: PackedScene = preload("res://systems/weapons/weapon.tscn")


func _ramp(duration: float = 0.5) -> SpinUp:
	var ramp: SpinUp = SpinUp.new()
	ramp.configure(duration)
	return ramp


func _gun(duration: float = 0.5, shooter: Player = null) -> Weapon:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	var data: WeaponData = WeaponData.new()
	data.rounds_per_minute = 800.0
	data.spin_up_time = duration
	data.pellets = 0
	data.magazine_size = 150
	var weapon: Weapon = WEAPON.instantiate() as Weapon
	weapon.setup(WeaponInstance.new(data), shooter, camera)
	camera.add_child(weapon)
	weapon.set_process(false)
	weapon.set_active(true)
	weapon.trigger_held = true
	return weapon


func test_first_interval_is_base_divided_by_forty_percent() -> void:
	assert_almost_eq(_ramp().scale_interval(BASE_INTERVAL), BASE_INTERVAL / 0.4, 0.00001)


func test_rate_ramps_linearly_and_reaches_base_at_half_a_second() -> void:
	var ramp: SpinUp = _ramp()
	ramp.tick(0.25, true)
	assert_almost_eq(ramp.scale_interval(BASE_INTERVAL), BASE_INTERVAL / 0.7, 0.00001)
	ramp.tick(0.25, true)
	assert_almost_eq(ramp.scale_interval(BASE_INTERVAL), BASE_INTERVAL, 0.00001)
	ramp.tick(10.0, true)
	assert_almost_eq(ramp.scale_interval(BASE_INTERVAL), BASE_INTERVAL, 0.00001, "full speed is capped")


func test_release_resets_and_a_second_trigger_hold_starts_slow() -> void:
	var ramp: SpinUp = _ramp()
	ramp.tick(0.5, true)
	ramp.tick(0.0, false)
	assert_almost_eq(ramp.scale_interval(BASE_INTERVAL), BASE_INTERVAL / 0.4, 0.00001)
	ramp.tick(0.25, true)
	assert_almost_eq(ramp.scale_interval(BASE_INTERVAL), BASE_INTERVAL / 0.7, 0.00001)


func test_zero_is_off_and_is_the_default_for_existing_guns() -> void:
	var data: WeaponData = WeaponData.new()
	assert_eq(data.spin_up_time, 0.0)
	var ramp: SpinUp = _ramp(data.spin_up_time)
	for held: bool in [true, true, false, true]:
		ramp.tick(0.5, held)
		assert_eq(ramp.scale_interval(BASE_INTERVAL), BASE_INTERVAL)


func test_separate_guns_do_not_share_ramp_state() -> void:
	var first: SpinUp = _ramp()
	var second: SpinUp = _ramp()
	first.tick(0.5, true)
	assert_eq(first.scale_interval(BASE_INTERVAL), BASE_INTERVAL)
	assert_almost_eq(second.scale_interval(BASE_INTERVAL), BASE_INTERVAL / 0.4, 0.00001)


func test_ramp_progress_uses_elapsed_time_independent_of_tick_size() -> void:
	var coarse: SpinUp = _ramp()
	var fine: SpinUp = _ramp()
	coarse.tick(0.25, true)
	for frame: int in 15:
		fine.tick(1.0 / 60.0, true)
	assert_almost_eq(fine.scale_interval(BASE_INTERVAL), coarse.scale_interval(BASE_INTERVAL), 0.00001)


func test_sound_rises_with_the_ramp_and_stops_on_release_or_disable() -> void:
	var audio: AudioStreamPlayer = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.data = PackedByteArray([0, 0, 0, 0])
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 4
	audio.stream = stream
	add_child_autofree(audio)
	var ramp: SpinUp = SpinUp.new()
	ramp.configure(0.5, audio)
	ramp.tick(0.0, true)
	assert_true(audio.playing)
	assert_almost_eq(audio.pitch_scale, 0.6, 0.00001)
	ramp.tick(0.25, true)
	assert_almost_eq(audio.pitch_scale, 0.9, 0.00001)
	ramp.tick(0.25, true)
	assert_almost_eq(audio.pitch_scale, 1.2, 0.00001)
	ramp.tick(0.0, false)
	assert_false(audio.playing)
	assert_almost_eq(audio.pitch_scale, 0.6, 0.00001)
	ramp.tick(0.5, true)
	ramp.configure(0.0, audio)
	ramp.tick(0.5, true)
	assert_false(audio.playing, "disabled spin-up does not play a layer")


func test_weapon_schedules_the_slow_first_interval_then_reaches_base() -> void:
	var weapon: Weapon = _gun()
	weapon.tick(0.0)
	assert_eq(weapon.instance.ammo_in_mag, 149, "press fires immediately")
	assert_almost_eq(weapon._shot_timer, BASE_INTERVAL / 0.4, 0.00001)
	for frame: int in 30:
		weapon.tick(1.0 / 60.0)
	weapon._shot_timer = 0.0
	weapon.tick(0.0)
	assert_almost_eq(weapon._shot_timer, BASE_INTERVAL, 0.00001, "held for 0.5 seconds reaches 800 rpm")


func test_nonzero_first_tick_keeps_the_first_scheduled_interval_at_forty_percent() -> void:
	var weapon: Weapon = _gun()
	var delta: float = 1.0 / 60.0
	weapon.tick(delta)
	assert_almost_eq(weapon._shot_timer + delta, BASE_INTERVAL / 0.4, 0.00001)


func test_weapon_catch_up_shots_sample_their_own_time_within_a_tick() -> void:
	var coarse: Weapon = _gun()
	var fine: Weapon = _gun()
	coarse.tick(0.0)
	fine.tick(0.0)
	for frame: int in 60:
		fine.tick(1.0 / 60.0)
	coarse.tick(0.5)
	coarse.tick(0.5)
	assert_eq(fine.instance.ammo_in_mag, coarse.instance.ammo_in_mag)
	assert_almost_eq(fine._shot_timer, coarse._shot_timer, 0.00001)


func test_weapon_release_and_reequip_restart_the_ramp() -> void:
	var weapon: Weapon = _gun()
	weapon.tick(0.5)
	weapon.trigger_held = false
	weapon.tick(0.0)
	weapon.trigger_held = true
	weapon._shot_timer = 0.0
	weapon.tick(0.0)
	assert_almost_eq(weapon._shot_timer, BASE_INTERVAL / 0.4, 0.00001, "release clears the ramp")
	weapon.tick(0.5)
	weapon.set_active(false)
	weapon.set_active(true)
	weapon._shot_timer = 0.0
	weapon.tick(0.0)
	assert_almost_eq(weapon._shot_timer, BASE_INTERVAL / 0.4, 0.00001, "holstering clears the ramp")


func test_weapon_reload_and_sprint_cannot_precharge_the_ramp() -> void:
	var weapon: Weapon = _gun()
	weapon.tick(0.5)
	assert_true(weapon.start_reload())
	assert_almost_eq(weapon._spin_up.scale_interval(BASE_INTERVAL), BASE_INTERVAL / 0.4, 0.00001)
	weapon.tick(weapon.data.reload_time * 0.5)
	assert_almost_eq(weapon._spin_up.scale_interval(BASE_INTERVAL), BASE_INTERVAL / 0.4, 0.00001)
	weapon.tick(weapon.data.reload_time)
	weapon.sprinting = true
	weapon.tick(0.5)
	assert_almost_eq(weapon._spin_up.scale_interval(BASE_INTERVAL), BASE_INTERVAL / 0.4, 0.00001)
	weapon.sprinting = false
	weapon._sprint_block = 0.0
	weapon._shot_timer = 0.0
	weapon.tick(0.0)
	assert_almost_eq(weapon._shot_timer, BASE_INTERVAL / 0.4, 0.00001, "sprinting clears the ramp")


func test_fire_interval_serum_stacks_with_spin_up_and_zero_keeps_existing_timing() -> void:
	var shooter: Player = Player.new()
	autofree(shooter)
	var serum: SerumData = SerumData.new()
	serum.multipliers[&"fire_interval"] = 0.5
	shooter.serums.append(serum)
	var weapon: Weapon = _gun(0.5, shooter)
	weapon.tick(0.0)
	assert_almost_eq(weapon._shot_timer, BASE_INTERVAL / 0.4 * 0.5, 0.00001)
	var ordinary: Weapon = _gun(0.0, shooter)
	ordinary.tick(0.0)
	assert_almost_eq(ordinary._shot_timer, BASE_INTERVAL * 0.5, 0.00001)


func test_zero_keeps_ordinary_automatic_fire_cadence() -> void:
	var weapon: Weapon = _gun(0.0)
	weapon.tick(0.0)
	for frame: int in 60:
		weapon.tick(1.0 / 60.0)
	assert_eq(weapon.instance.ammo_in_mag, 136, "800 rpm fires 14 rounds including the initial shot in one second")
	assert_eq(weapon.data.spin_up_time, 0.0, "live spin-up state never changes content")

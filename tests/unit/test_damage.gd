extends GutTest


func test_damage_falloff() -> void:
	var w: WeaponData = WeaponData.new()
	w.damage = 40.0
	w.min_damage = 20.0
	w.falloff_start = 10.0
	w.falloff_end = 30.0
	assert_eq(w.get_damage_at(5.0), 40.0)
	assert_almost_eq(w.get_damage_at(20.0), 30.0, 0.001)
	assert_eq(w.get_damage_at(100.0), 20.0)


func test_zone_multipliers() -> void:
	var w: WeaponData = WeaponData.new()
	w.head_multiplier = 2.0
	w.limb_multiplier = 0.5
	assert_eq(w.get_zone_multiplier(DamageInfo.Zone.HEAD), 2.0)
	assert_eq(w.get_zone_multiplier(DamageInfo.Zone.BODY), 1.0)
	assert_eq(w.get_zone_multiplier(DamageInfo.Zone.LIMB), 0.5)


func test_health_component_dies_once() -> void:
	var h: HealthComponent = HealthComponent.new()
	add_child_autofree(h)
	h.reset(100.0)
	watch_signals(h)
	h.take_damage(DamageInfo.create(60.0, null))
	assert_eq(h.current, 40.0)
	h.take_damage(DamageInfo.create(60.0, null))
	h.take_damage(DamageInfo.create(60.0, null))
	assert_true(h.is_dead)
	assert_signal_emit_count(h, "died", 1)


func test_health_regen_runs_in_the_physics_tick_on_the_authority() -> void:
	var h: HealthComponent = _regen_health()
	add_child_autofree(h)
	h.set_physics_process(false)
	h.take_damage(DamageInfo.create(50.0, null))
	h._physics_process(1.0)
	assert_eq(h.current, 50.0, "no regen before the delay")
	h._physics_process(1.0)
	assert_almost_eq(h.current, 60.0, 0.001)
	assert_false(h.has_method("_process"), "regen is gameplay, not a render-frame visual")


func test_health_regen_does_not_run_on_a_client_copy() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", 24651), OK)
	root.multiplayer.multiplayer_peer = peer
	var h: HealthComponent = _regen_health()
	root.add_child(h)
	h.set_physics_process(false)
	h.take_damage(DamageInfo.create(50.0, null))
	h._physics_process(5.0)
	assert_eq(h.current, 50.0, "only the server heals; clients get the value from snapshots")
	peer.close()
	get_tree().set_multiplayer(null, root.get_path())


func _regen_health() -> HealthComponent:
	var h: HealthComponent = HealthComponent.new()
	h.regen_delay = 2.0
	h.regen_per_second = 10.0
	h.max_health = 100.0
	return h


func test_hit_zone_applies_zone() -> void:
	var h: HealthComponent = HealthComponent.new()
	add_child_autofree(h)
	h.reset(100.0)
	var zone: HitZone = HitZone.new()
	zone.health = h
	zone.zone = DamageInfo.Zone.HEAD
	zone.damage_multiplier = 1.5
	add_child_autofree(zone)
	var info: DamageInfo = DamageInfo.create(20.0, null)
	zone.receive_hit(info)
	assert_true(info.is_headshot())
	assert_eq(h.current, 70.0)


func test_weapon_instance_reload_math() -> void:
	var w: WeaponData = WeaponData.new()
	w.magazine_size = 30
	w.starting_reserve = 40
	w.max_reserve = 90
	var inst: WeaponInstance = WeaponInstance.new(w)
	inst.ammo_in_mag = 5
	assert_eq(inst.refill_magazine(), 25)
	assert_eq(inst.ammo_reserve, 15)
	inst.ammo_in_mag = 0
	assert_eq(inst.refill_magazine(), 15)
	assert_eq(inst.ammo_in_mag, 15)
	assert_false(inst.needs_reload())
	inst.add_reserve(500)
	assert_eq(inst.ammo_reserve, 90)
	assert_eq(w.starting_reserve, 40, "data is never mutated")


func test_recoil_pattern_repeats_tail() -> void:
	var r: RecoilData = RecoilData.new()
	r.pattern = [Vector2(0, 1), Vector2(0, 2), Vector2(0, 3), Vector2(0, 4)]
	r.random_spread = Vector2.ZERO
	r.repeat_last = 2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	assert_eq(r.get_kick(0, rng).y, 1.0)
	assert_eq(r.get_kick(3, rng).y, 4.0)
	assert_eq(r.get_kick(4, rng).y, 3.0)
	assert_eq(r.get_kick(5, rng).y, 4.0)

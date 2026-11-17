## Both-barrel fire shares the normal trigger, traces and live ammunition state.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WEAPON: PackedScene = preload("res://systems/weapons/weapon.tscn")

var player: Player
var weapon: Weapon
var hits: Array[Vector3] = []
var damage_events: Array[DamageInfo] = []


func before_each() -> void:
	hits.clear()
	damage_events.clear()
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.get_rng().seed = 17
	player.position = Vector3(100, 100, 100)
	_gun(10)
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(20, 20, 0.5)
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.global_position = player.camera.global_position + Vector3(0, 0, -3)
	await wait_physics_frames(2)


func _gun(pellets: int, double_barrel: bool = true) -> void:
	var data: WeaponData = WeaponData.new()
	data.id = &"coachman_2b" if pellets == 10 else &"grubber_sawnoff"
	data.loot_tags = [&"shotgun"]
	if double_barrel:
		data.loot_tags.append(&"double")
	data.fire_mode = WeaponData.FireMode.SEMI
	data.pellets = pellets
	data.magazine_size = 2
	data.starting_reserve = 0
	data.rounds_per_minute = 200.0
	data.hip_spread = 0.0
	data.ads_spread = 0.0
	data.spread_per_shot = 0.0
	weapon = WEAPON.instantiate() as Weapon
	weapon.setup(WeaponInstance.new(data), player, player.camera)
	player.camera.add_child(weapon)
	weapon.set_active(true)
	weapon.traced.connect(func(point: Vector3, _normal: Vector3, _kind: Impact.Kind) -> void: hits.append(point))
	watch_signals(weapon)


func _alt() -> void:
	player.last_frame.buttons = DoubleBarrel.ALT_FIRE
	weapon.tick(1.0 / 60.0)


func _damageable_target() -> HealthComponent:
	var target: Node3D = Node3D.new()
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 10000.0
	target.add_child(health)
	health.damaged.connect(func(info: DamageInfo) -> void: damage_events.append(info))
	var zone: HitZone = HitZone.new()
	zone.health = health
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(20, 20, 0.5)
	zone.add_child(shape)
	target.add_child(zone)
	add_child_autofree(target)
	target.global_position = player.camera.global_position + Vector3(0, 0, -2)
	return health


func test_alt_fire_empties_both_barrels_with_one_firing_event() -> void:
	_alt()
	assert_eq(weapon.instance.ammo_in_mag, 0)
	assert_eq(hits.size(), 20, "Coachman sends twenty pellets through the normal trace")
	assert_signal_emit_count(weapon, "fired", 1, "one simultaneous shot drives sound and recoil")
	assert_eq(weapon.data.magazine_size, 2, "firing never edits the authored magazine")
	assert_eq(weapon.data.pellets, 10, "firing never edits the authored pellet count")


func test_grubber_reuses_the_same_alt_fire() -> void:
	weapon.free()
	_gun(8)
	_alt()
	assert_eq(weapon.instance.ammo_in_mag, 0)
	assert_eq(hits.size(), 16, "Grubber fires two eight-pellet barrels")
	assert_signal_emit_count(weapon, "fired", 1)


func test_primary_fire_uses_one_barrel() -> void:
	weapon.trigger_held = true
	weapon.tick(1.0 / 60.0)
	assert_eq(weapon.instance.ammo_in_mag, 1)
	assert_eq(hits.size(), 10)
	assert_signal_emit_count(weapon, "fired", 1)


func test_alt_with_one_round_falls_back_to_a_normal_shot() -> void:
	weapon.instance.ammo_in_mag = 1
	_alt()
	assert_eq(weapon.instance.ammo_in_mag, 0)
	assert_eq(hits.size(), 10, "one remaining shell cannot become a double blast")
	assert_signal_emit_count(weapon, "fired", 1)


func test_holding_alt_does_not_repeat_a_semi_auto_shot() -> void:
	_alt()
	weapon.instance.ammo_in_mag = 2
	weapon.tick(1.0)
	assert_eq(weapon.instance.ammo_in_mag, 2, "holding alt across a refill is still one press")
	assert_signal_emit_count(weapon, "fired", 1)
	player.last_frame.buttons = 0
	weapon.tick(1.0 / 60.0)
	_alt()
	assert_eq(weapon.instance.ammo_in_mag, 0)
	assert_signal_emit_count(weapon, "fired", 2)


func test_alt_fire_obeys_the_normal_fire_interval() -> void:
	weapon.trigger_held = true
	weapon.tick(1.0 / 60.0)
	weapon.trigger_held = false
	_alt()
	assert_eq(weapon.instance.ammo_in_mag, 1, "alt cannot bypass a primary shot's cooldown")
	assert_eq(hits.size(), 10)


func test_alt_fire_does_not_interrupt_reload() -> void:
	weapon.instance.ammo_in_mag = 1
	weapon.instance.ammo_reserve = 10
	assert_true(weapon.start_reload())
	_alt()
	assert_true(weapon.is_reloading())
	assert_eq(weapon.instance.ammo_in_mag, 1)
	assert_eq(hits.size(), 0)


func test_alt_fire_is_blocked_while_sprinting_or_inactive() -> void:
	weapon.sprinting = true
	_alt()
	assert_eq(weapon.instance.ammo_in_mag, 2)
	assert_eq(hits.size(), 0)
	weapon.sprinting = false
	weapon.set_active(false)
	weapon.tick(1.0)
	assert_eq(weapon.instance.ammo_in_mag, 2)
	assert_eq(hits.size(), 0)


func test_simultaneous_primary_and_alt_is_one_double_blast() -> void:
	weapon.trigger_held = true
	_alt()
	assert_eq(weapon.instance.ammo_in_mag, 0)
	assert_eq(hits.size(), 20)
	assert_signal_emit_count(weapon, "fired", 1)


func test_alt_does_not_fire_a_gun_without_the_double_tag() -> void:
	weapon.free()
	_gun(10, false)
	_alt()
	assert_eq(weapon.instance.ammo_in_mag, 2)
	assert_eq(hits.size(), 0)


func test_alt_hit_zone_receives_knockback_in_every_pellets_damage_info() -> void:
	var health: HealthComponent = _damageable_target()
	await wait_physics_frames(2)
	_alt()
	assert_eq(damage_events.size(), 20, "all pellets use HitZone and HealthComponent")
	assert_almost_eq(health.current, 10000.0 - weapon.data.damage * 20.0, 0.001)
	assert_false(health.is_dead, "the target survives every pellet")
	for info: DamageInfo in damage_events:
		assert_eq(info.weapon_id, weapon.data.id)
		assert_eq(info.attacker, player)
		assert_eq(info.impulse, Vector3(0, 0, -8), "server-side receivers get the alt impulse")


func test_primary_and_single_round_fallback_keep_the_normal_hit_impulse() -> void:
	var health: HealthComponent = _damageable_target()
	await wait_physics_frames(2)
	weapon.trigger_held = true
	weapon.tick(1.0 / 60.0)
	assert_eq(damage_events.size(), 10)
	for info: DamageInfo in damage_events:
		assert_eq(info.impulse, Vector3(0, 0, -2), "primary fire keeps normal flinch feedback")
	damage_events.clear()
	weapon.free()
	_gun(10)
	weapon.instance.ammo_in_mag = 1
	_alt()
	assert_eq(damage_events.size(), 10)
	assert_false(health.is_dead)
	for info: DamageInfo in damage_events:
		assert_eq(info.impulse, Vector3(0, 0, -2), "one barrel cannot produce double-barrel knockback")

## Pierce uses real physics rays through Spawner-created zombies and the shared hit path.
extends GutTest

const WEAPON: PackedScene = preload("res://systems/weapons/weapon.tscn")

var _session: GameSession
var _spawner: Spawner
var _camera: Camera3D
var _weapon: Weapon
var _zombies: Array[Zombie] = []


func before_each() -> void:
	_session = GameSession.new()
	_session.rng.seed = 19
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_pierce_spawns")
	add_child_autofree(marker)
	_spawner = Spawner.new()
	_spawner.session = _session
	_spawner.spawn_group = &"test_pierce_spawns"
	add_child_autofree(_spawner)
	_zombies.clear()
	for index: int in 3:
		var zombie: Zombie = _spawner.spawn(
			Content.enemy(&"zombie_walker"), 1, load("res://content/waves/default_waves.tres") as WaveRules
		)
		zombie.set_physics_process(false)
		zombie.set_process(false)
		zombie.visual.set_process(false)
		zombie.visual.position = Vector3.ZERO
		zombie.position = Vector3(0, 0, -3.0 - index * 3.0)
		zombie.rotation = Vector3.ZERO
		zombie.head_zone.global_position = zombie.position + Vector3.UP * 1.68
		zombie.health.reset(1000.0)
		_zombies.append(zombie)
	var data: WeaponData = WeaponData.new()
	data.id = &"pierce_test"
	data.damage = 100.0
	data.min_damage = 100.0
	data.hip_spread = 0.0
	data.max_range = 20.0
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0.8, 0)
	add_child_autofree(_camera)
	_weapon = WEAPON.instantiate() as Weapon
	_weapon.setup(WeaponInstance.new(data), null, _camera)
	_camera.add_child(_weapon)
	_weapon.set_active(true)
	watch_signals(_weapon)
	await wait_physics_frames(2)


func after_each() -> void:
	_session.free()


func _wall(distance: float, thickness: float = 0.02) -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	wall.position = Vector3(0, 0.8, -distance)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2, 2, thickness)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)


func _assert_health(expected: Array[float]) -> void:
	for index: int in _zombies.size():
		assert_almost_eq(_zombies[index].health.current, expected[index], 0.001, "zombie %d" % index)


func test_default_zero_only_hits_the_first_zombie() -> void:
	assert_eq(_weapon.data.pierce_count, 0)
	_weapon.fire()
	_assert_health([900.0, 1000.0, 1000.0])
	assert_signal_emit_count(_weapon, "hit_landed", 1)


func test_pierce_one_hits_two_zombies_with_twenty_percent_less_damage() -> void:
	_weapon.data.pierce_count = 1
	_weapon.fire()
	_assert_health([900.0, 920.0, 1000.0])
	assert_signal_emit_count(_weapon, "hit_landed", 2)


func test_pierce_two_hits_three_zombies_with_compounding_falloff() -> void:
	_weapon.data.pierce_count = 2
	_weapon.fire()
	_assert_health([900.0, 920.0, 936.0])
	assert_signal_emit_count(_weapon, "traced", 3)
	assert_signal_emit_count(_weapon, "hit_landed", 3)


func test_wall_before_the_first_zombie_stops_every_hit() -> void:
	_weapon.data.pierce_count = 2
	_wall(1.5)
	await wait_physics_frames(2)
	_weapon.fire()
	_assert_health([1000.0, 1000.0, 1000.0])
	assert_signal_emit_count(_weapon, "traced", 1)
	assert_signal_not_emitted(_weapon, "hit_landed")


func test_thin_wall_after_a_zombie_stops_piercing() -> void:
	_weapon.data.pierce_count = 2
	_wall(4.5, 0.002)
	await wait_physics_frames(2)
	_weapon.fire()
	_assert_health([900.0, 1000.0, 1000.0])
	assert_signal_emit_count(_weapon, "traced", 2)
	assert_signal_emit_count(_weapon, "hit_landed", 1)


func test_a_wall_containing_the_continuation_origin_stops_piercing() -> void:
	_weapon.data.pierce_count = 2
	_wall(2.776, 0.0008)
	await wait_physics_frames(2)
	_weapon.fire()
	_assert_health([900.0, 1000.0, 1000.0])
	assert_signal_emit_count(_weapon, "traced", 2)
	assert_signal_emit_count(_weapon, "hit_landed", 1)


func test_a_wall_within_one_millimetre_after_the_hit_is_not_skipped() -> void:
	_weapon.data.pierce_count = 2
	_wall(2.7753, 0.0002)
	await wait_physics_frames(2)
	_weapon.fire()
	_assert_health([900.0, 1000.0, 1000.0])
	assert_signal_emit_count(_weapon, "traced", 2)
	assert_signal_emit_count(_weapon, "hit_landed", 1)


func test_overlapping_head_and_body_count_as_one_zombie() -> void:
	_weapon.data.pierce_count = 1
	_weapon.data.head_multiplier = 3.0
	_zombies[0].head_zone.global_position = Vector3(0, 0.8, -2.7)
	await wait_physics_frames(2)
	watch_signals(_zombies[0].health)
	_weapon.fire()
	_assert_health([700.0, 920.0, 1000.0])
	assert_signal_emit_count(_zombies[0].health, "damaged", 1)
	var info: DamageInfo = get_signal_parameters(_zombies[0].health, "damaged")[0] as DamageInfo
	assert_eq(info.weapon_id, _weapon.data.id)
	assert_true(info.is_headshot())
	assert_eq(get_signal_parameters(_weapon, "hit_landed", 0), [false, true])


func test_falloff_uses_distance_from_the_original_shooter() -> void:
	_weapon.data.pierce_count = 2
	_weapon.data.falloff_start = 0.0
	_weapon.data.falloff_end = 10.0
	_weapon.data.min_damage = 50.0
	_weapon.fire()
	for index: int in _zombies.size():
		var distance: float = 3.0 + index * 3.0 - 0.225
		var damage: float = _weapon.data.get_damage_at(distance) * pow(0.8, index)
		assert_almost_eq(_zombies[index].health.current, 1000.0 - damage, 0.01)


func test_piercing_does_not_extend_the_original_max_range() -> void:
	_weapon.data.pierce_count = 2
	_weapon.data.max_range = 7.0
	_weapon.fire()
	_assert_health([900.0, 920.0, 1000.0])


func test_a_non_zombie_hit_zone_stops_the_ray() -> void:
	_weapon.data.pierce_count = 2
	var health: HealthComponent = HealthComponent.new()
	add_child_autofree(health)
	var zone: HitZone = HitZone.new()
	zone.health = health
	zone.position = Vector3(0, 0.8, -1.5)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	zone.add_child(shape)
	add_child_autofree(zone)
	await wait_physics_frames(2)
	_weapon.fire()
	_assert_health([1000.0, 1000.0, 1000.0])
	assert_true(health.is_dead)

## The Siphon orb travels before opening its well and sweeps for the first surface.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")

var _root: Node3D
var _attacker: Player
var _claims: Claims


class Claims:
	extends Node

	var points: Array[Vector3] = []

	func request_well(point: Vector3) -> void:
		points.append(point)


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)
	_attacker = PLAYER.instantiate() as Player
	_root.add_child(_attacker)
	_attacker.set_physics_process(false)
	_attacker.local_input.enabled = false
	_claims = Claims.new()
	_root.add_child(_claims)


func _orb(use_claims: bool = true) -> GravityWell:
	var orb: GravityWell = GravityWell.spawn_orb(
		_root, _attacker, Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, _claims if use_claims else null
	)
	orb.set_physics_process(false)
	return orb


func test_orb_travels_slowly_and_makes_no_early_claim() -> void:
	var orb: GravityWell = _orb()
	assert_eq(orb.global_position, Vector3(0.0, 1.0, 0.0))
	assert_eq(_claims.points.size(), 0)
	orb._tick_orb(0.5)
	assert_eq(orb.global_position, Vector3(0.0, 1.0, -5.0))
	assert_false(orb.collapsed)
	assert_eq(_claims.points.size(), 0)


func test_orb_stops_at_twenty_five_metres_and_claims_once() -> void:
	var orb: GravityWell = _orb()
	orb._tick_orb(2.4)
	assert_eq(_claims.points.size(), 0)
	orb._tick_orb(0.2)
	assert_true(orb.collapsed)
	assert_eq(_claims.points.size(), 1)
	assert_eq(_claims.points[0], Vector3(0.0, 1.0, -25.0))


func test_long_frame_sweeps_to_first_surface() -> void:
	var first: StaticBody3D = _wall(-8.0)
	_wall(-12.0)
	await wait_physics_frames(1)
	var orb: GravityWell = _orb()
	orb._tick_orb(10.0)
	assert_true(orb.collapsed)
	assert_eq(_claims.points.size(), 1)
	assert_almost_eq(_claims.points[0].z, first.global_position.z + 0.2, 0.01)


func test_well_only_opens_after_orb_arrives_and_has_no_instant_damage() -> void:
	var session: GameSession = GameSession.new()
	session.rng.seed = 7
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_siphon_orb_spawns")
	_root.add_child(marker)
	var spawner: Spawner = Spawner.new()
	spawner.session = session
	spawner.spawn_group = &"test_siphon_orb_spawns"
	_root.add_child(spawner)
	var zombie: Zombie = spawner.spawn(WALKER, 1, RULES)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(3.0, 0.0, -25.0)
	zombie.health.reset(1000.0)
	var orb: GravityWell = _orb(false)
	orb._tick_orb(2.4)
	assert_eq(zombie.health.current, 1000.0)
	assert_null(_active_well())
	orb._tick_orb(0.1)
	var well: GravityWell = _active_well()
	assert_not_null(well)
	assert_eq(zombie.health.current, 1000.0)
	if well:
		well.set_physics_process(false)
		well.tick(0.5)
		assert_lt(zombie.health.current, 1000.0)
	session.free()


func _wall(z: float) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4.0, 4.0, 0.4)
	collision.shape = shape
	wall.add_child(collision)
	_root.add_child(wall)
	wall.global_position = Vector3(0.0, 1.0, z)
	return wall


func _active_well() -> GravityWell:
	for child: Node in _root.get_children():
		var well: GravityWell = child as GravityWell
		if well and well.is_in_group(&"gravity_wells") and not well.collapsed:
			return well
	return null

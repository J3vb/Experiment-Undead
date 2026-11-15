## Siphon wells pull a bounded crowd and apply their total damage only on the server.
extends GutTest

const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")
const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const TOTAL_DAMAGE: float = 40.0 * 0.57

var _root: Node3D
var _session: GameSession
var _spawner: Spawner
var _attacker: Player


func before_each() -> void:
	_session = GameSession.new()
	_session.rng.seed = 7
	_root = Node3D.new()
	add_child_autofree(_root)
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_gravity_well_spawns")
	_root.add_child(marker)
	_spawner = Spawner.new()
	_spawner.session = _session
	_spawner.spawn_group = &"test_gravity_well_spawns"
	_root.add_child(_spawner)
	_attacker = PLAYER.instantiate() as Player
	_root.add_child(_attacker)
	_attacker.set_physics_process(false)
	_attacker.local_input.enabled = false


func after_each() -> void:
	_session.free()


func _zombie(point: Vector3) -> Zombie:
	var zombie: Zombie = _spawner.spawn(WALKER, 1, RULES)
	zombie.set_physics_process(false)
	zombie.global_position = point
	zombie.state = Zombie.State.CHASING
	zombie.health.reset(1000.0)
	return zombie


func _well() -> GravityWell:
	var well: GravityWell = GravityWell.new()
	_root.add_child(well)
	well.setup(_attacker, Vector3.ZERO, TOTAL_DAMAGE)
	well.set_physics_process(false)
	return well


func test_pulls_at_most_twelve_zombies() -> void:
	var crowd: Array[Zombie] = []
	var starting: Array[Vector3] = []
	for index: int in 15:
		var angle: float = TAU * float(index) / 15.0
		var point: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 5.0
		crowd.append(_zombie(point))
		starting.append(point)
	var well: GravityWell = _well()
	well.tick(0.5)
	var pulled: int = 0
	var damaged: int = 0
	for index: int in crowd.size():
		if crowd[index].global_position.distance_to(starting[index]) > 0.01:
			pulled += 1
		if crowd[index].health.current < 1000.0:
			damaged += 1
	assert_eq(pulled, 12)
	assert_eq(damaged, 12)


func test_only_zombies_within_six_metres_are_pulled_and_damaged() -> void:
	var inside: Zombie = _zombie(Vector3(5.9, 0.0, 0.0))
	var boundary: Zombie = _zombie(Vector3(-6.0, 0.0, 0.0))
	var outside: Zombie = _zombie(Vector3(6.01, 0.0, 0.0))
	var above: Zombie = _zombie(Vector3(0.0, 6.01, 0.0))
	var well: GravityWell = _well()
	well.tick(0.5)
	assert_lt(inside.global_position.length(), 5.9)
	assert_lt(boundary.global_position.length(), 6.0)
	assert_lt(inside.health.current, 1000.0)
	assert_lt(boundary.health.current, 1000.0)
	assert_eq(outside.global_position, Vector3(6.01, 0.0, 0.0))
	assert_eq(above.global_position, Vector3(0.0, 6.01, 0.0))
	assert_eq(outside.health.current, 1000.0)
	assert_eq(above.health.current, 1000.0)


func test_damage_is_spread_over_time_and_totals_the_roster_value() -> void:
	var zombie: Zombie = _zombie(Vector3(1.0, 0.0, 0.0))
	var well: GravityWell = _well()
	well.tick(0.5)
	assert_gt(zombie.health.current, 1000.0 - TOTAL_DAMAGE)
	assert_almost_eq(zombie.health.current, 1000.0 - TOTAL_DAMAGE / 6.0, 0.001)
	for _pulse: int in 5:
		well.tick(0.5)
	assert_almost_eq(zombie.health.current, 1000.0 - TOTAL_DAMAGE, 0.001)
	assert_true(well.collapsed)


func test_collapses_at_three_seconds_and_stops_applying_damage() -> void:
	var zombie: Zombie = _zombie(Vector3(1.0, 0.0, 0.0))
	var well: GravityWell = _well()
	well.tick(2.9)
	assert_false(well.collapsed)
	well.tick(0.1)
	assert_true(well.collapsed)
	var after_collapse: float = zombie.health.current
	well.tick(10.0)
	assert_eq(zombie.health.current, after_collapse)
	assert_almost_eq(after_collapse, 1000.0 - TOTAL_DAMAGE, 0.001)


func test_a_long_final_tick_never_overpays_the_total_damage() -> void:
	var zombie: Zombie = _zombie(Vector3(1.0, 0.0, 0.0))
	var well: GravityWell = _well()
	well.tick(0.37)
	well.tick(0.81)
	well.tick(10.0)
	assert_true(well.collapsed)
	assert_almost_eq(zombie.health.current, 1000.0 - TOTAL_DAMAGE, 0.001)


func test_cosmetic_well_cannot_pull_or_damage() -> void:
	var point: Vector3 = Vector3(4.0, 0.0, 0.0)
	var zombie: Zombie = _zombie(point)
	var well: GravityWell = _well()
	well.gameplay = false
	well.tick(3.0)
	assert_eq(zombie.global_position, point)
	assert_eq(zombie.health.current, 1000.0)
	assert_true(well.collapsed)


func test_well_stops_when_its_attacker_is_freed() -> void:
	var point: Vector3 = Vector3(4.0, 0.0, 0.0)
	var zombie: Zombie = _zombie(point)
	var well: GravityWell = _well()
	_attacker.free()
	well.tick(0.5)
	assert_true(well.collapsed)
	assert_eq(zombie.global_position, point)
	assert_eq(zombie.health.current, 1000.0)


func test_maximum_two_wells_per_player_and_expiry_frees_a_slot() -> void:
	var first: GravityWell = GravityWell.open(_root, _attacker, Vector3.ZERO, TOTAL_DAMAGE)
	var second: GravityWell = GravityWell.open(_root, _attacker, Vector3.ZERO, TOTAL_DAMAGE)
	assert_not_null(first)
	assert_not_null(second)
	first.set_physics_process(false)
	second.set_physics_process(false)
	assert_null(GravityWell.open(_root, _attacker, Vector3.ZERO, TOTAL_DAMAGE))
	first.tick(3.0)
	var replacement: GravityWell = GravityWell.open(_root, _attacker, Vector3.ZERO, TOTAL_DAMAGE)
	assert_not_null(replacement)
	replacement.set_physics_process(false)


func test_each_player_has_their_own_two_well_limit() -> void:
	var other: Player = PLAYER.instantiate() as Player
	_root.add_child(other)
	other.set_physics_process(false)
	other.local_input.enabled = false
	for _slot: int in 2:
		var well: GravityWell = GravityWell.open(_root, _attacker, Vector3.ZERO, TOTAL_DAMAGE)
		well.set_physics_process(false)
	var other_well: GravityWell = GravityWell.open(_root, other, Vector3.ZERO, TOTAL_DAMAGE)
	assert_not_null(other_well)
	other_well.set_physics_process(false)


func test_client_cannot_enable_gameplay_on_its_cosmetic_copy() -> void:
	var client_root: Node3D = Node3D.new()
	_root.add_child(client_root)
	var path: NodePath = client_root.get_path()
	get_tree().set_multiplayer(SceneMultiplayer.new(), path)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", 24664), OK)
	client_root.multiplayer.multiplayer_peer = peer
	var point: Vector3 = Vector3(4.0, 0.0, 0.0)
	var zombie: Zombie = _zombie(point)
	zombie.reparent(client_root)
	var well: GravityWell = GravityWell.new()
	client_root.add_child(well)
	well.setup(_attacker, Vector3.ZERO, TOTAL_DAMAGE)
	well.set_physics_process(false)
	well.gameplay = true
	well.tick(0.5)
	assert_false(client_root.multiplayer.is_server())
	assert_eq(zombie.global_position, point)
	assert_eq(zombie.health.current, 1000.0)
	await wait_process_frames(1)
	peer.close()
	client_root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	client_root.free()
	get_tree().set_multiplayer(null, path)


func test_delayed_cosmetic_well_replaces_the_oldest_display() -> void:
	var first: GravityWell = GravityWell.open(_root, _attacker, Vector3.ZERO, 0.0, true)
	var second: GravityWell = GravityWell.open(_root, _attacker, Vector3.ONE, 0.0, true)
	first.set_physics_process(false)
	second.set_physics_process(false)
	var newest: GravityWell = GravityWell.open(_root, _attacker, Vector3(2.0, 0.0, 0.0), 0.0, true)
	assert_not_null(newest)
	assert_true(first.collapsed)
	assert_false(second.collapsed)
	assert_false(newest.collapsed)
	newest.set_physics_process(false)

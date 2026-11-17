## Head pops and the Gore setting: headshot kills collapse the head bone and
## throw chunks on Full only; late-joined corpses get the stump without the
## show; Reduced and Off keep the head and lay less or no blood.
extends GutTest

const WALKER: String = "res://content/enemies/zombie_walker.tres"
const BLOATER: String = "res://content/enemies/zombie_bloater.tres"

var _parent: Node3D
var _gore_before: Variant


func before_each() -> void:
	_gore_before = Settings.get_value(&"graphics", &"gore")
	HeadPop._ring.clear()
	HeadPop._next = 0
	BloodPool._ring.clear()
	BloodPool._next = 0
	_parent = Node3D.new()
	add_child_autofree(_parent)


func after_each() -> void:
	Settings._values[&"graphics"][&"gore"] = _gore_before
	for pool: BloodPool in BloodPool._ring:
		if is_instance_valid(pool):
			pool.free()
	for pop: HeadPop in HeadPop._ring:
		if is_instance_valid(pop):
			pop.free()
	BloodPool._ring.clear()
	HeadPop._ring.clear()


func _gore(level: Impact.Gore) -> void:
	Settings._values[&"graphics"][&"gore"] = level


func _zombie(path: String = WALKER) -> Zombie:
	var data: EnemyData = load(path) as EnemyData
	var zombie: Zombie = data.scene.instantiate() as Zombie
	zombie.setup(data, 1, 1.0, 1.0, 1.0, RandomNumberGenerator.new())
	_parent.add_child(zombie)
	zombie.set_process(false)
	zombie.set_physics_process(false)
	return zombie


func test_ninth_head_pop_reuses_the_oldest() -> void:
	var first: HeadPop = HeadPop.spawn(_parent, Vector3.ZERO)
	for index: int in HeadPop.MAX_ALIVE - 1:
		HeadPop.spawn(_parent, Vector3(index, 1, 0))
	assert_eq(HeadPop._ring.size(), HeadPop.MAX_ALIVE)
	assert_same(HeadPop.spawn(_parent, Vector3(0, 1, 5)), first)
	assert_eq(first.chunks.size(), HeadPop.CHUNKS)


func test_chunks_freeze_then_the_pop_hides() -> void:
	var pop: HeadPop = HeadPop.spawn(_parent, Vector3(0, 1.7, 0))
	assert_false(pop.chunks[0].freeze, "chunks fly first")
	pop._physics_process(HeadPop.FREEZE_TIME)
	for chunk: RigidBody3D in pop.chunks:
		assert_true(chunk.freeze, "chunks settle after 1.5 s")
	assert_true(pop.visible)
	pop._physics_process(HeadPop.LIFETIME)
	assert_false(pop.visible, "hidden after 10 s")
	assert_false(pop.is_physics_processing())


func test_pop_head_collapses_the_head_bone_on_both_models() -> void:
	for path: String in [WALKER, BLOATER]:
		var zombie: Zombie = _zombie(path)
		assert_almost_eq(zombie.visual.head_scale(), 1.0, 0.01)
		zombie.visual.pop_head()
		assert_lt(zombie.visual.head_scale(), 0.05, "%s head shrinks into the neck" % path.get_file())
		zombie.free()


func test_headshot_kill_on_full_pops_the_head_with_chunks_and_splats() -> void:
	_gore(Impact.Gore.FULL)
	var zombie: Zombie = _zombie()
	zombie.visual.fall_over(true)
	assert_lt(zombie.visual.head_scale(), 0.05)
	assert_eq(HeadPop._ring.size(), 1, "one head pop")
	assert_eq(BloodPool._ring.size(), 1 + BloodPool.SPLATS, "a big pool and its splats")
	zombie.free()


func test_body_kill_keeps_the_head() -> void:
	_gore(Impact.Gore.FULL)
	var zombie: Zombie = _zombie()
	zombie.visual.fall_over(false)
	assert_almost_eq(zombie.visual.head_scale(), 1.0, 0.01)
	assert_eq(HeadPop._ring.size(), 0)
	zombie.free()


func test_reduced_and_off_never_decapitate() -> void:
	for level: Impact.Gore in [Impact.Gore.REDUCED, Impact.Gore.OFF]:
		_gore(level)
		var zombie: Zombie = _zombie()
		zombie.visual.fall_over(true)
		assert_almost_eq(zombie.visual.head_scale(), 1.0, 0.01, "gore %d keeps the head" % level)
		zombie.free()
	assert_eq(HeadPop._ring.size(), 0)


func test_reduced_lays_short_lived_pools_up_to_eight() -> void:
	_gore(Impact.Gore.REDUCED)
	for index: int in 10:
		BloodPool.lay_death(_parent, Vector3(index, 0, 0))
	assert_eq(BloodPool._ring.size(), BloodPool.REDUCED_ALIVE)
	assert_almost_eq(BloodPool._ring[2]._left, BloodPool.REDUCED_LIFETIME, 0.001)


func test_off_lays_no_pool_and_hits_make_dust() -> void:
	_gore(Impact.Gore.OFF)
	BloodPool.lay_death(_parent, Vector3.ZERO)
	assert_eq(BloodPool._ring.size(), 0, "no blood pools with gore off")
	var impact: Impact = Impact.spawn(_parent, Vector3.ONE, Vector3.UP, Impact.Kind.HEAD)
	assert_false(impact._flesh.visible, "no blood burst")
	assert_true(impact._surface.visible, "grey dust instead")


func test_reduced_bursts_half_the_blood() -> void:
	_gore(Impact.Gore.REDUCED)
	var impact: Impact = Impact.spawn(_parent, Vector3.ONE, Vector3.UP, Impact.Kind.FLESH)
	assert_eq(impact._flesh.amount, Impact.REDUCED_PARTICLES)
	_gore(Impact.Gore.FULL)
	impact = Impact.spawn(_parent, Vector3.ONE, Vector3.UP, Impact.Kind.FLESH)
	assert_eq(impact._flesh.amount, Impact.BLOOD_PARTICLES)


func test_late_joined_corpse_gets_the_stump_but_no_show() -> void:
	_gore(Impact.Gore.FULL)
	var zombie: Zombie = _zombie()
	zombie.head_popped = true
	zombie.state = Zombie.State.DEAD
	var sync: ZombieSync = ZombieSync.new()
	sync._zombie = zombie
	sync._physics_process(0.0)
	assert_lt(zombie.visual.head_scale(), 0.05, "the head is still missing")
	assert_eq(HeadPop._ring.size(), 0, "no chunks for a corpse that was already down")
	assert_eq(BloodPool._ring.size(), 0, "no fresh pool either")
	sync.free()
	zombie.free()


func test_client_copy_seen_alive_shows_the_whole_pop() -> void:
	_gore(Impact.Gore.FULL)
	var zombie: Zombie = _zombie()
	var sync: ZombieSync = ZombieSync.new()
	sync._zombie = zombie
	zombie.state = Zombie.State.CHASING
	sync._physics_process(0.0)
	zombie.head_popped = true
	zombie.state = Zombie.State.DEAD
	sync._physics_process(0.0)
	sync._physics_process(0.0)
	assert_eq(HeadPop._ring.size(), 1, "one pop, shown once")
	assert_lt(zombie.visual.head_scale(), 0.05)
	sync.free()
	zombie.free()

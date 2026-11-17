## Blood pools reuse the oldest of at most 24 quads, share one mesh,
## fade out over their last seconds and appear under every falling zombie.
extends GutTest

const WALKER: String = "res://content/enemies/zombie_walker.tres"

var _parent: Node3D


func before_each() -> void:
	BloodPool._ring.clear()
	BloodPool._next = 0
	_parent = Node3D.new()
	add_child_autofree(_parent)


func test_twenty_fifth_pool_reuses_the_oldest() -> void:
	var first: BloodPool = BloodPool.spawn(_parent, Vector3.ZERO)
	for index: int in BloodPool.MAX_ALIVE - 1:
		BloodPool.spawn(_parent, Vector3(index, 0, 0))
	assert_eq(_parent.get_child_count(), BloodPool.MAX_ALIVE)
	var reused: BloodPool = BloodPool.spawn(_parent, Vector3(0, 0, 9))
	assert_same(reused, first)
	assert_eq(_parent.get_child_count(), BloodPool.MAX_ALIVE)
	assert_almost_eq(reused.global_position.z, 9.0, 0.001)
	assert_same(reused.mesh, (_parent.get_child(1) as BloodPool).mesh, "mesh and material are shared")


func test_pool_fades_and_hides_after_its_lifetime() -> void:
	var pool: BloodPool = BloodPool.spawn(_parent, Vector3.ZERO)
	pool._process(BloodPool.LIFETIME - BloodPool.FADE_TIME * 0.5)
	assert_true(pool.visible)
	assert_almost_eq(pool.transparency, 0.5, 0.01, "half faded in the last seconds")
	pool._process(BloodPool.FADE_TIME)
	assert_false(pool.visible)
	assert_false(pool.is_processing())


func test_falling_zombie_leaves_one_pool() -> void:
	var data: EnemyData = load(WALKER) as EnemyData
	var zombie: Zombie = data.scene.instantiate() as Zombie
	zombie.setup(data, 1, 1.0, 1.0, 1.0, RandomNumberGenerator.new())
	_parent.add_child(zombie)
	zombie.position = Vector3(3, 0, 2)
	var before: int = BloodPool._ring.size()
	zombie.visual.fall_over()
	assert_eq(BloodPool._ring.size(), before + 1, "one pool per fallen zombie")
	assert_almost_eq(BloodPool._ring[-1].global_position.x, 3.0, 0.01)
	zombie.free()

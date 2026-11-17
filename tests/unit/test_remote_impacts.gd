## Teammates' shots carry their real hits: each hit shows an impact of the
## kind the shooter saw, and the server drops malformed hit lists.
extends GutTest

const RIFLE: String = "res://content/weapons/rifle_ar.tres"

var _effects: RemoteShotEffects


func before_each() -> void:
	Impact._ring.clear()
	Impact._next = 0
	_effects = RemoteShotEffects.new()
	add_child_autofree(_effects)


func test_each_hit_shows_an_impact_of_its_kind() -> void:
	var hits: PackedVector3Array = [Vector3(1, 1, -3), Vector3(1, 1.6, -4), Vector3(0, 0.5, -6)]
	var kinds: PackedByteArray = [Impact.Kind.FLESH, Impact.Kind.HEAD, Impact.Kind.SURFACE]
	_effects.show_hits(Vector3.ZERO, hits, kinds)
	assert_eq(Impact._ring.size(), 3)
	assert_true(Impact._ring[0]._flesh.visible, "body hit bleeds")
	assert_true(Impact._ring[1]._flesh.visible, "head hit bleeds")
	assert_false(Impact._ring[2]._flesh.visible, "wall hit makes dust")
	assert_almost_eq(Impact._ring[1].global_position.distance_to(hits[1]), 0.0, 0.02)
	assert_gt(Impact._ring[0].global_position.z, hits[0].z, "impact faces back toward the shooter")


func test_a_shot_that_hit_nothing_shows_no_impacts() -> void:
	_effects.play(load(RIFLE) as WeaponData, Vector3.ZERO, PackedVector3Array([Vector3.FORWARD * 10.0]))
	_effects.show_hits(Vector3.ZERO, PackedVector3Array(), PackedByteArray())
	assert_eq(Impact._ring.size(), 0)


func test_bad_hit_lists_are_dropped() -> void:
	var shots: RemoteShots = RemoteShots.new()
	var one: PackedVector3Array = [Vector3.ONE]
	assert_true(shots._valid_hits(8, one, PackedByteArray([Impact.Kind.HEAD])))
	assert_true(shots._valid_hits(1, PackedVector3Array(), PackedByteArray()), "a miss has no hits")
	assert_false(shots._valid_hits(8, one, PackedByteArray()), "one kind per hit")
	assert_false(shots._valid_hits(8, one, PackedByteArray([3])), "unknown impact kind")
	assert_false(shots._valid_hits(8, PackedVector3Array([Vector3(INF, 0, 0)]), PackedByteArray([1])), "not finite")
	var many: PackedVector3Array = []
	many.resize(8 * RemoteShots.MAX_HITS_PER_PELLET + 1)
	var many_kinds: PackedByteArray = []
	many_kinds.resize(many.size())
	assert_false(shots._valid_hits(8, many, many_kinds), "more hits than pierce allows")
	shots.free()


func test_pierced_and_killing_hits_keep_the_kind_the_shooter_saw() -> void:
	var shots: RemoteShots = RemoteShots.new()
	shots._hits.append(Vector3.ONE)
	shots._kinds.append(Impact.Kind.FLESH)
	var zone: HitZone = HitZone.new()
	zone.zone = DamageInfo.Zone.HEAD
	zone.set_enabled(false)
	shots._kinds.append(Impact.kind_for(zone))
	shots._hits.append(Vector3.ONE * 2.0)
	assert_eq(shots._kinds[1], Impact.Kind.HEAD, "a killing head hit (zones already off) still relays as HEAD")
	assert_true(shots._valid_hits(1, shots._hits, shots._kinds), "two pierced hits from one pellet are allowed")
	zone.free()
	shots.free()

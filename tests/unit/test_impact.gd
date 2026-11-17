## Impacts reuse the oldest of at most 48 nodes and share their meshes and materials.
extends GutTest

const WEAPON: String = "res://systems/weapons/weapon.tscn"
const RIFLE: String = "res://content/weapons/rifle_ar.tres"
const WALKER: String = "res://content/enemies/zombie_walker.tres"

var _parent: Node3D


func before_each() -> void:
	Impact._ring.clear()
	Impact._next = 0
	Impact._sounds.clear()
	Impact._next_sound = 0
	_parent = Node3D.new()
	add_child_autofree(_parent)


func _impacts(parent: Node) -> int:
	var count: int = 0
	for child: Node in parent.get_children():
		if child is Impact:
			count += 1
	return count


func test_sixty_spawns_keep_at_most_forty_eight_nodes() -> void:
	var first: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	for index: int in 59:
		Impact.spawn(_parent, Vector3(index, 0, 0), Vector3.UP, Impact.Kind.SURFACE)
	assert_eq(_impacts(_parent), Impact.MAX_ALIVE)
	assert_false(first.is_queued_for_deletion())


func test_spawn_after_the_cap_reuses_the_oldest_at_the_new_point() -> void:
	var first: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.FLESH)
	for index: int in Impact.MAX_ALIVE - 1:
		Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.FLESH)
	var reused: Impact = Impact.spawn(_parent, Vector3(5, 0, 0), Vector3.UP, Impact.Kind.SURFACE)
	assert_same(reused, first)
	assert_almost_eq(reused.global_position, Vector3(5, 0.01, 0), Vector3.ONE * 0.001)
	assert_true(reused._surface.visible and reused._surface.emitting)
	assert_false(reused._flesh.visible)
	assert_true(reused._mark.visible)


func test_impacts_of_a_kind_share_mesh_and_material() -> void:
	var a: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	var b: Impact = Impact.spawn(_parent, Vector3.ONE, Vector3.UP, Impact.Kind.SURFACE)
	assert_same(a._surface.mesh, b._surface.mesh)
	assert_same((a._surface.mesh as QuadMesh).material, (b._surface.mesh as QuadMesh).material)
	assert_same(a._mark.mesh, b._mark.mesh)
	assert_same(a._flesh.mesh, b._flesh.mesh)


func test_impact_hides_after_its_lifetime() -> void:
	var impact: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.FLESH)
	assert_true(impact.visible)
	impact._process(Impact.FLESH_LIFETIME + 0.01)
	assert_false(impact.visible)
	assert_false(impact.is_processing())


func test_freed_parent_does_not_break_the_ring() -> void:
	var old_parent: Node3D = Node3D.new()
	add_child(old_parent)
	for index: int in Impact.MAX_ALIVE:
		Impact.spawn(old_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	old_parent.free()
	var impact: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	assert_true(is_instance_valid(impact))
	assert_same(impact.get_parent(), _parent)


func test_impact_under_another_parent_moves_to_the_new_one() -> void:
	var other: Node3D = Node3D.new()
	add_child_autofree(other)
	var first: Impact = Impact.spawn(other, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	for index: int in Impact.MAX_ALIVE - 1:
		Impact.spawn(other, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	assert_same(Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE), first)
	assert_same(first.get_parent(), _parent)


func test_flesh_hits_play_on_at_most_four_reused_sound_players() -> void:
	Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.SURFACE)
	assert_eq(Impact._sounds.size(), 0, "surface hits make no flesh sound")
	for index: int in 6:
		Impact.spawn(_parent, Vector3(index, 0, 0), Vector3.UP, Impact.Kind.FLESH)
	assert_eq(Impact._sounds.size(), Impact.MAX_SOUNDS)
	var players: int = 0
	for child: Node in _parent.get_children():
		if child is AudioStreamPlayer3D:
			players += 1
	assert_eq(players, Impact.MAX_SOUNDS, "the oldest player is reused")
	assert_almost_eq(Impact._sounds[1].global_position.x, 5.0, 0.02, "sixth hit reused the second player")


func test_head_hits_crack_and_body_hits_squelch() -> void:
	var body: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.FLESH)
	assert_true(Impact._sounds[0].stream in Impact.FLESH_SOUNDS)
	assert_true(body._flesh.visible, "body hits bleed")
	var head: Impact = Impact.spawn(_parent, Vector3.ZERO, Vector3.UP, Impact.Kind.HEAD)
	assert_true(Impact._sounds[1].stream in Impact.HEAD_SOUNDS)
	assert_true(head._flesh.visible, "head hits bleed")
	assert_eq(head._flesh.amount, Impact.BLOOD_PARTICLES)


func test_impact_kind_comes_from_the_hit_zone() -> void:
	var zone: HitZone = HitZone.new()
	zone.zone = DamageInfo.Zone.HEAD
	assert_eq(Impact.kind_for(zone), Impact.Kind.HEAD)
	zone.zone = DamageInfo.Zone.BODY
	assert_eq(Impact.kind_for(zone), Impact.Kind.FLESH)
	assert_eq(Impact.kind_for(null), Impact.Kind.SURFACE)
	zone.set_enabled(false)
	zone.zone = DamageInfo.Zone.HEAD
	assert_eq(Impact.kind_for(zone), Impact.Kind.HEAD, "a killing head hit keeps its kind")
	zone.free()


func _trace_kinds(zone_name: String, health: float) -> Array[Impact.Kind]:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	var weapon: Weapon = (load(WEAPON) as PackedScene).instantiate() as Weapon
	weapon.setup(WeaponInstance.new(load(RIFLE) as WeaponData), null, camera)
	camera.add_child(weapon)
	var data: EnemyData = load(WALKER) as EnemyData
	var zombie: Zombie = data.scene.instantiate() as Zombie
	zombie.setup(data, 1, 1.0, 1.0, 1.0, RandomNumberGenerator.new())
	add_child_autofree(zombie)
	zombie.health.reset(health)
	var zone: HitZone = zombie.head_zone if zone_name == "head" else zombie.hit_zones[-1]
	var kinds: Array[Impact.Kind] = []
	weapon.traced.connect(func(_point: Vector3, _normal: Vector3, kind: Impact.Kind) -> void: kinds.append(kind))
	var hit: Dictionary = {"position": Vector3.ZERO, "normal": Vector3.BACK, "collider": zone, "damage_scale": 1.0}
	weapon._hit(hit, Vector3(0, 0, 5), Vector3.FORWARD)
	return kinds


func test_weapon_trace_sends_head_for_a_head_hit_even_when_it_kills() -> void:
	assert_eq(_trace_kinds("head", 1000.0), [Impact.Kind.HEAD] as Array[Impact.Kind])
	assert_eq(_trace_kinds("head", 1.0), [Impact.Kind.HEAD] as Array[Impact.Kind], "lethal head hit stays HEAD")


func test_weapon_trace_sends_flesh_for_a_body_hit() -> void:
	assert_eq(_trace_kinds("body", 1000.0), [Impact.Kind.FLESH] as Array[Impact.Kind])

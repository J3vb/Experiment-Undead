## The server picks chain and frost from WeaponData.effect, so a new gun file
## with an effect works without code naming its id.
extends GutTest

const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")
const RIFLE: WeaponData = preload("res://content/weapons/rifle_ar.tres")

var _session: GameSession
var _spawner: Spawner
var _claims: HitClaims


func before_each() -> void:
	_session = GameSession.new()
	_session.rng.seed = 11
	_spawner = Spawner.new()
	_spawner.session = _session
	_spawner.spawn_group = &"test_weapon_effect_spawn"
	add_child_autofree(_spawner)
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_weapon_effect_spawn")
	_spawner.add_child(marker)
	_claims = HitClaims.new()
	_claims.session = _session
	add_child_autofree(_claims)


func after_each() -> void:
	_session.free()


func _zombie(point: Vector3) -> Zombie:
	var zombie: Zombie = _spawner.spawn(WALKER, 1, RULES)
	zombie.set_physics_process(false)
	zombie.position = point
	zombie.health.reset(1000.0)
	return zombie


func _effect_gun(id: StringName, effect: WeaponData.Effect) -> void:
	var gun: WeaponData = RIFLE.duplicate() as WeaponData
	gun.id = id
	gun.effect = effect
	_claims._weapons[id] = gun


func _hit(zombie: Zombie, weapon_id: StringName) -> void:
	var info: DamageInfo = DamageInfo.create(10.0, self)
	info.weapon_id = weapon_id
	_claims.apply_server_hit(zombie.hit_zones[1], info)


func test_any_chain_gun_chains_on_a_server_hit() -> void:
	_effect_gun(&"test_chain", WeaponData.Effect.CHAIN)
	var source: Zombie = _zombie(Vector3.ZERO)
	var neighbour: Zombie = _zombie(Vector3(1.0, 0.0, 0.0))
	_hit(source, RIFLE.id)
	assert_eq(neighbour.health.current, 1000.0, "a gun with no effect does not chain")
	_hit(source, &"test_chain")
	assert_lt(neighbour.health.current, 1000.0, "the effect field chains, whatever the id")


func test_any_frost_gun_freezes_on_server_hits() -> void:
	_effect_gun(&"test_frost", WeaponData.Effect.FROST)
	var zombie: Zombie = _zombie(Vector3.ZERO)
	for _shot: int in Frost.HITS_TO_FREEZE:
		_hit(zombie, RIFLE.id)
	assert_false(zombie.frozen, "a gun with no effect does not freeze")
	for _shot: int in Frost.HITS_TO_FREEZE:
		_hit(zombie, &"test_frost")
	assert_true(zombie.frozen, "the effect field freezes, whatever the id")


func test_unknown_weapon_id_applies_plain_damage() -> void:
	var zombie: Zombie = _zombie(Vector3.ZERO)
	var neighbour: Zombie = _zombie(Vector3(1.0, 0.0, 0.0))
	_hit(zombie, &"no_such_gun")
	assert_lt(zombie.health.current, 1000.0)
	assert_eq(neighbour.health.current, 1000.0)
	assert_false(zombie.frozen)

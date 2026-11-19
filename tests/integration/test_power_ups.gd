## Power-up drops in a real match: the drop roll, the per-round cap, Resupply
## refilling every gun, the two pickups' looks, and a drop timing out.
extends GutTest

const SESSION: PackedScene = preload("res://systems/game/game_session.tscn")

var session: GameSession
var player: Player
var drops: PowerUpDrops


func before_each() -> void:
	session = SESSION.instantiate() as GameSession
	session.profile_id = &""
	session.rng_seed = 7
	add_child_autofree(session)
	await wait_until(func() -> bool: return session.level.is_navigation_ready, 15.0, "navmesh baked")
	session.director.stop()
	player = session.get_players()[0]
	drops = session.power_up_drops


func _kill_somewhere() -> void:
	var corpse: Node3D = Node3D.new()
	add_child_autofree(corpse)
	corpse.global_position = Vector3(40, 0, 40)
	Events.enemy_killed.emit(corpse, DamageInfo.create(1.0, null))


func _pickups() -> Array[PowerUp]:
	var out: Array[PowerUp] = []
	for node: Node in session.level.get_children():
		if node is PowerUp and not node.is_queued_for_deletion():
			out.append(node as PowerUp)
	return out


func test_no_drop_when_the_roll_fails() -> void:
	drops.drop_chance = 0.0
	_kill_somewhere()
	assert_eq(_pickups().size(), 0)


func test_drop_floats_above_the_kill() -> void:
	drops.drop_chance = 1.0
	_kill_somewhere()
	assert_eq(_pickups().size(), 1)
	assert_eq(_pickups()[0].data.id, &"resupply")
	assert_almost_eq(_pickups()[0].global_position, Vector3(40, 0.8, 40), Vector3.ONE * 0.01)


func test_drop_cap_per_round() -> void:
	drops.drop_chance = 1.0
	for i: int in drops.max_per_round + 2:
		_kill_somewhere()
	assert_eq(_pickups().size(), drops.max_per_round)
	Events.round_started.emit(2, 10)
	_kill_somewhere()
	assert_eq(_pickups().size(), drops.max_per_round + 1, "the cap resets each round")


func test_ammo_drop_rates_after_the_first_play_test() -> void:
	var fresh: PowerUpDrops = PowerUpDrops.new()
	assert_eq(fresh.drop_chance, 0.01, "Resupply is the only power-up yet, so it drops less than the GDD 2.5%")
	assert_eq(fresh.max_per_round, 1)
	assert_eq(fresh.ammo_pack_chance, 0.05, "Scavenger packs halved")
	fresh.free()


func test_resupply_and_ammo_pack_look_different() -> void:
	var resupply: PowerUp = drops.drop(Content.get_item(&"power_ups", &"resupply") as PowerUpData, Vector3(40, 0, 40))
	var pack: PowerUp = drops._spawn(Content.get_item(&"power_ups", &"ammo_pack") as PowerUpData, Vector3(42, 0, 40))
	var big: MeshInstance3D = resupply.get_node(^"Visual/Core") as MeshInstance3D
	var small: MeshInstance3D = pack.get_node(^"Visual/Core") as MeshInstance3D
	assert_gt(big.scale.x, small.scale.x * 2.0, "Resupply is much bigger")
	var green: Color = (big.material_override as StandardMaterial3D).emission
	var orange: Color = (small.material_override as StandardMaterial3D).emission
	assert_gt(green.g, green.r, "Resupply glows green")
	assert_gt(orange.r, orange.g, "an ammo pack glows orange")
	assert_ne((resupply.get_node(^"Visual/Label") as Label3D).text, (pack.get_node(^"Visual/Label") as Label3D).text)


func test_resupply_fills_every_gun() -> void:
	for weapon: Weapon in player.weapons.weapons:
		weapon.instance.ammo_in_mag = 1
		weapon.instance.ammo_reserve = 0
	var pickup: PowerUp = drops.drop(Content.get_item(&"power_ups", &"resupply") as PowerUpData, Vector3.ZERO)
	pickup.collect(player)
	for weapon: Weapon in player.weapons.weapons:
		assert_eq(weapon.instance.ammo_in_mag, weapon.data.magazine_size)
		assert_eq(weapon.instance.ammo_reserve, weapon.data.max_reserve)
	assert_true(pickup.is_queued_for_deletion(), "used up")


func test_walking_into_it_collects_it() -> void:
	player.weapons.current.instance.ammo_reserve = 0
	var pickup: PowerUp = drops.drop(Content.get_item(&"power_ups", &"resupply") as PowerUpData, player.global_position)
	await wait_physics_frames(3)
	assert_false(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "picked up")
	assert_eq(player.weapons.current.instance.ammo_reserve, player.weapons.current.data.max_reserve)


func test_drop_vanishes_after_25_seconds() -> void:
	var pickup: PowerUp = drops.drop(Content.get_item(&"power_ups", &"resupply") as PowerUpData, Vector3(40, 0, 40))
	pickup._physics_process(24.0)
	assert_false(pickup.is_queued_for_deletion())
	pickup._physics_process(1.5)
	assert_true(pickup.is_queued_for_deletion())


func _kill_by(killer: Player) -> void:
	var corpse: Node3D = Node3D.new()
	add_child_autofree(corpse)
	corpse.global_position = Vector3(40, 0, 40)
	Events.enemy_killed.emit(corpse, DamageInfo.create(1.0, killer))


func test_scavenger_kills_drop_ammo_packs() -> void:
	drops.drop_chance = 0.0
	drops.ammo_pack_chance = 1.0
	_kill_by(player)
	assert_eq(_pickups().size(), 0, "no Scavenger, no pack")
	player.add_serum(load("res://content/serums/scavenger.tres") as SerumData)
	for i: int in 6:
		_kill_by(player)
	assert_eq(_pickups().size(), 6, "packs do not count toward the power-up cap")
	assert_eq(_pickups()[0].data.id, &"ammo_pack")
	assert_eq(drops.dropped_this_round, 0)


func test_ammo_pack_adds_one_magazine_to_every_gun() -> void:
	for weapon: Weapon in player.weapons.weapons:
		weapon.instance.ammo_reserve = 0
	var pack: PowerUp = drops._spawn(Content.get_item(&"power_ups", &"ammo_pack") as PowerUpData, Vector3(40, 0, 40))
	pack.collect(player)
	for weapon: Weapon in player.weapons.weapons:
		assert_eq(weapon.instance.ammo_reserve, weapon.data.magazine_size)

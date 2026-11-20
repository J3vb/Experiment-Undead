## Frag grenades (docs/plans/frag-grenades.md, step 1): cook timer, throw, refill,
## blast falloff, walls, the thrower's own damage cap, no teammate damage, Bloater burst,
## and (step 3) cook sounds and blast shake.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const BLOATER: EnemyData = preload("res://content/enemies/zombie_bloater.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")
const RIFLE: WeaponData = preload("res://content/weapons/rifle_ar.tres")

var root: Node3D
var session: GameSession
var spawner: Spawner
var player: Player
var thrower: GrenadeThrower
var frag: ThrowableData


func before_each() -> void:
	session = GameSession.new()
	session.rng.seed = 5
	root = Node3D.new()
	add_child_autofree(root)
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_grenade_spawns")
	root.add_child(marker)
	spawner = Spawner.new()
	spawner.session = session
	spawner.spawn_group = &"test_grenade_spawns"
	root.add_child(spawner)
	player = _player(Vector3(0, -50, 0))
	player.weapons.give(RIFLE)
	player.weapons.tick(1.0)
	thrower = player.grenades
	frag = GrenadeThrower.FRAG.duplicate() as ThrowableData
	thrower.data = frag


func after_each() -> void:
	session.free()


func _player(at: Vector3) -> Player:
	var made: Player = PLAYER.instantiate() as Player
	root.add_child(made)
	made.set_physics_process(false)
	made.local_input.enabled = false
	made.global_position = at
	return made


func _frame(held: bool) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.buttons = InputFrame.LETHAL if held else 0
	return frame


func _zombie(at: Vector3, data: EnemyData = WALKER, health: float = 1000.0) -> Zombie:
	var zombie: Zombie = spawner.spawn(data, 1, RULES)
	zombie.set_physics_process(false)
	zombie.global_position = at
	zombie.health.reset(health)
	return zombie


func _blast(at: Vector3) -> void:
	var point: Node3D = Node3D.new()
	root.add_child(point)
	point.global_position = at
	Blast.apply(point, at, frag, player)


func _grenades() -> Array[Grenade]:
	var out: Array[Grenade] = []
	for node: Node in root.get_children():
		if node is Grenade:
			out.append(node as Grenade)
	return out


func test_frag_numbers_from_the_plan() -> void:
	var data: ThrowableData = GrenadeThrower.FRAG
	assert_eq(data.carry, 2, "game-design.md: 2 frag grenades")
	assert_eq(data.fuse, 3.0)
	assert_eq(data.radius, 7.0)
	assert_eq(data.full_radius, 1.5)
	assert_eq(data.self_damage_max, 60.0)
	assert_eq(data.centre_damage, 1000.0, "fixed centre damage (person's pick)")
	assert_eq(thrower.count, 2, "a player starts with a full carry")


func test_falloff_is_full_inside_then_linear_to_zero() -> void:
	assert_eq(Blast.falloff(frag, 0.0), 1.0)
	assert_eq(Blast.falloff(frag, 1.5), 1.0)
	assert_almost_eq(Blast.falloff(frag, 4.25), 0.5, 0.001)
	assert_eq(Blast.falloff(frag, 7.0), 0.0)
	assert_eq(Blast.falloff(frag, 8.0), 0.0)


func test_cook_spends_the_fuse_and_release_throws_with_the_rest() -> void:
	thrower.tick(_frame(true), 0.0)
	assert_true(thrower.cooking)
	assert_true(player.weapons.is_swapping(), "the gun is down while cooking")
	thrower.tick(_frame(true), 1.0)
	assert_almost_eq(thrower.fuse_left, 2.0, 0.001)
	thrower.tick(_frame(false), 0.0)
	assert_false(thrower.cooking)
	assert_eq(thrower.count, 1)
	var thrown: Array[Grenade] = _grenades()
	assert_eq(thrown.size(), 1)
	assert_almost_eq(thrown[0].fuse_left, 2.0, 0.001)
	assert_gt(thrown[0].linear_velocity.length(), 14.0, "thrown at about 15 m/s")
	assert_gt(thrown[0].linear_velocity.y, 0.0, "the throw leaves above the aim line")


func test_holding_past_the_fuse_blows_up_in_hand() -> void:
	player.global_position = Vector3(0, 0, 0)
	thrower.tick(_frame(true), 0.0)
	for i: int in 4:
		thrower.tick(_frame(true), 1.0)
	assert_false(thrower.cooking, "the fuse ran out")
	var thrown: Array[Grenade] = _grenades()
	assert_eq(thrown.size(), 1)
	assert_eq(thrown[0].fuse_left, 0.0)
	await wait_physics_frames(2)
	assert_eq(player.health.current, 100.0 - frag.self_damage_max, "own grenade hurts, capped at 60")


func test_no_throw_without_grenades_and_holding_does_not_restart() -> void:
	thrower.count = 0
	thrower.tick(_frame(true), 0.0)
	assert_false(thrower.cooking)
	thrower.count = 1
	thrower.tick(_frame(true), 0.0)
	assert_false(thrower.cooking, "a key still held from before is not a new press")


func test_refill_on_round_start_never_takes_extras() -> void:
	thrower.count = 0
	Events.round_started.emit(2, 10)
	assert_eq(thrower.count, 2)
	thrower.count = 3
	thrower.refill()
	assert_eq(thrower.count, 3)


func test_blast_falls_off_with_distance() -> void:
	var near: Zombie = _zombie(Vector3(0, 0, 1))
	var mid: Zombie = _zombie(Vector3(4.25, -1.1, 0))
	var far: Zombie = _zombie(Vector3(0, -1.1, 8))
	await wait_physics_frames(2)
	_blast(Vector3.ZERO)
	assert_true(near.health.is_dead, "inside 1.5 m takes full damage")
	assert_almost_eq(mid.health.current, 500.0, 1.0, "half way out takes half")
	assert_eq(far.health.current, 1000.0, "outside the radius takes none")


func test_blast_damage_is_explosive_and_belongs_to_the_thrower() -> void:
	_zombie(Vector3(0, -1.1, 3))
	await wait_physics_frames(2)
	watch_signals(Events)
	_blast(Vector3.ZERO)
	var hit: Array = get_signal_parameters(Events, "enemy_damaged")
	assert_eq((hit[1] as DamageInfo).damage_type, DamageInfo.Type.EXPLOSIVE)
	assert_eq((hit[1] as DamageInfo).attacker, player)
	assert_signal_emitted(Events, "hit_confirmed")


func test_walls_block_the_blast() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.global_position = Vector3(0, 0, 1.5)
	var hidden: Zombie = _zombie(Vector3(0, -1.1, 3))
	var open: Zombie = _zombie(Vector3(0, -1.1, -3))
	await wait_physics_frames(2)
	_blast(Vector3.ZERO)
	assert_eq(hidden.health.current, 1000.0, "the wall stops it")
	assert_lt(open.health.current, 1000.0)


func test_thrower_damage_is_capped_and_teammates_take_none() -> void:
	player.global_position = Vector3.ZERO
	var friend: Player = _player(Vector3(1, 0, 0))
	await wait_physics_frames(2)
	_blast(Vector3(0, 0.5, 0))
	assert_eq(player.health.current, 100.0 - frag.self_damage_max)
	assert_eq(friend.health.current, 100.0, "no friendly fire")


func test_bloater_bursts_from_any_explosive_hit() -> void:
	var bloater: Zombie = _zombie(Vector3(6, -1.1, 0), BLOATER, 50000.0)
	var walker: Zombie = _zombie(Vector3(-6, -1.1, 0), WALKER, 50000.0)
	await wait_physics_frames(2)
	_blast(Vector3.ZERO)
	assert_true(bloater.health.is_dead, "explosives burst it at once")
	assert_false(walker.health.is_dead)


func test_a_resupply_without_a_drop_service_refills_grenades() -> void:
	var pickup: PowerUp = (load("res://systems/power_ups/power_up.tscn") as PackedScene).instantiate() as PowerUp
	pickup.data = Content.get_item(&"power_ups", &"resupply") as PowerUpData
	root.add_child(pickup)
	thrower.count = 0
	pickup.collect(player)
	assert_eq(thrower.count, frag.carry)


func test_soak_bot_throws_one_frag_a_round_only_at_far_zombies() -> void:
	var bot: Node = (load("res://tools/soak/soak_bot.gd") as GDScript).new()
	bot.set("player", player)
	add_child_autofree(bot)
	var eye: Vector3 = player.camera.global_position
	assert_true(bot.call("_wants_frag", eye + Vector3(0, 0, -10)), "a full carry and a far zombie")
	assert_false(bot.call("_wants_frag", eye + Vector3(0, 0, -5)), "too close: the bot would hurt itself")
	thrower.count = 1
	assert_false(bot.call("_wants_frag", eye + Vector3(0, 0, -10)), "only the first frag of the round")


func test_cook_plays_pin_then_ticks_every_half_second() -> void:
	thrower.tick(_frame(true), 0.0)
	var audio: AudioStreamPlayer = thrower.get_child(0) as AudioStreamPlayer
	assert_eq(audio.stream, GrenadeThrower.PIN_SOUND, "pin pull on the press")
	thrower.tick(_frame(true), 0.4)
	assert_eq(audio.stream, GrenadeThrower.PIN_SOUND, "no tick before 0.5 s")
	thrower.tick(_frame(true), 0.2)
	assert_eq(audio.stream, GrenadeThrower.TICK_SOUND, "tick at 0.5 s")


func test_blast_shake_falls_off_to_zero_at_fifteen_metres() -> void:
	assert_almost_eq(BlastEffect.shake_at(0.0), 0.6, 0.001)
	assert_almost_eq(BlastEffect.shake_at(7.5), 0.3, 0.001)
	assert_almost_eq(BlastEffect.shake_at(15.0), 0.0, 0.001)
	assert_almost_eq(BlastEffect.shake_at(40.0), 0.0, 0.001)


func test_blast_shake_follows_the_explosions_slider_and_skips_other_cameras() -> void:
	var saved: Variant = Settings.get_value(&"comfort", &"shake_hits")
	Settings._values[&"comfort"][&"shake_hits"] = 0.5
	var other: Player = _player(Vector3(0, -50, 0))
	player.camera.current = true
	BlastEffect.shake_local_players(get_tree(), player.camera.global_position)
	Settings._values[&"comfort"][&"shake_hits"] = saved
	assert_almost_eq(player.camera_rig.get_trauma(), 0.3, 0.001, "0.6 at the blast, halved by the slider")
	assert_eq(other.camera_rig.get_trauma(), 0.0, "a camera nobody looks through is not shaken")

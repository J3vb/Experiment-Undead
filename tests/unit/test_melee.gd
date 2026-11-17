## Knife swing (V): 150 MELEE damage within 2 m, one swing per 0.6 s, cancels a
## reload, and a knife kill pays the melee bonus (docs/plans/core-loop-gaps.md, step 4).
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")
const RIFLE: WeaponData = preload("res://content/weapons/rifle_ar.tres")

var player: Player
var spawner: Spawner
var session: GameSession
var eye: Camera3D


func before_each() -> void:
	session = GameSession.new()
	session.rng.seed = 3
	spawner = Spawner.new()
	spawner.session = session
	spawner.spawn_group = &"test_melee_spawn"
	add_child_autofree(spawner)
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_melee_spawn")
	spawner.add_child(marker)
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.global_position = Vector3(0, -50, 0)
	player.weapons.give(RIFLE)
	player.weapons.tick(1.0)
	eye = Camera3D.new()
	add_child_autofree(eye)
	eye.global_position = Vector3(0, 1.0, 0)
	player.weapons.melee.camera = eye
	watch_signals(Events)


func after_each() -> void:
	session.free()


func _zombie(distance: float, health: float = 1000.0) -> Zombie:
	var zombie: Zombie = spawner.spawn(WALKER, 1, RULES)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(0, 0, -distance)
	zombie.health.reset(health)
	await wait_physics_frames(2)
	return zombie


func test_swing_deals_150_melee_damage_within_reach() -> void:
	var zombie: Zombie = await _zombie(1.5)
	player.weapons.swing()
	assert_eq(zombie.health.current, 850.0)
	var hit: Array = get_signal_parameters(Events, "enemy_damaged")
	assert_eq((hit[1] as DamageInfo).damage_type, DamageInfo.Type.MELEE)
	assert_eq((hit[1] as DamageInfo).weapon_id, Melee.KNIFE.id)


func test_swing_misses_past_two_metres() -> void:
	var zombie: Zombie = await _zombie(2.5)
	player.weapons.swing()
	assert_eq(zombie.health.current, 1000.0)


func test_second_swing_inside_cooldown_does_nothing() -> void:
	var zombie: Zombie = await _zombie(1.5)
	player.weapons.swing()
	player.weapons.tick(0.5)
	player.weapons.swing()
	assert_eq(zombie.health.current, 850.0, "still swinging")
	player.weapons.tick(0.11)
	player.weapons.swing()
	assert_eq(zombie.health.current, 700.0)


func test_swing_blocks_the_gun_and_cancels_a_reload() -> void:
	var gun: Weapon = player.weapons.current
	gun.instance.ammo_in_mag = 5
	assert_true(gun.start_reload())
	player.weapons.swing()
	assert_false(gun.is_reloading(), "reload cancelled")
	player.weapons.set_trigger(true)
	assert_false(gun.trigger_held, "no firing mid swing")
	player.weapons.tick(Melee.swing_time())
	player.weapons.set_trigger(true)
	assert_true(gun.trigger_held)


func test_melee_key_swings_from_the_input_frame() -> void:
	var zombie: Zombie = await _zombie(1.5)
	var frame: InputFrame = InputFrame.new()
	frame.buttons = InputFrame.MELEE
	player.weapons.handle_presses(frame)
	assert_eq(zombie.health.current, 850.0)


func test_knife_kill_pays_the_melee_bonus() -> void:
	var economy: Economy = Economy.new()
	economy.rules = load("res://content/economy/default_economy.tres")
	add_child_autofree(economy)
	var before: int = player.wallet.points
	await _zombie(1.5, 100.0)
	player.weapons.swing()
	assert_signal_emit_count(Events, "enemy_killed", 1)
	assert_eq(player.wallet.points, before + economy.rules.points_per_hit + 130)

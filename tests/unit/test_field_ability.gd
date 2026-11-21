## Field abilities (docs/plans/field-abilities.md, step 1): pick by level, press and cooldown,
## kill credit, Gadgeteer and the 40% cap, and Shock Pulse's stun and push.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const WALKER: EnemyData = preload("res://content/enemies/zombie_walker.tres")
const RULES: WaveRules = preload("res://content/waves/default_waves.tres")
const SHOCK_PULSE: AbilityData = preload("res://content/abilities/shock_pulse.tres")

var root: Node3D
var session: GameSession
var spawner: Spawner
var player: Player
var ability: FieldAbility


func before_each() -> void:
	session = GameSession.new()
	session.rng.seed = 3
	root = Node3D.new()
	add_child_autofree(root)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = Layers.WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	shape.shape = box
	floor_body.add_child(shape)
	root.add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(&"test_ability_spawns")
	root.add_child(marker)
	spawner = Spawner.new()
	spawner.session = session
	spawner.spawn_group = &"test_ability_spawns"
	root.add_child(spawner)
	session.spawner = spawner
	player = PLAYER.instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	player.local_input.enabled = false
	player.session = session
	ability = player.abilities
	ability.ability = SHOCK_PULSE


func after_each() -> void:
	session.free()


func _press() -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.buttons = InputFrame.FIELD_ABILITY
	return frame


func _zombie(at: Vector3, state: Zombie.State = Zombie.State.CHASING) -> Zombie:
	var zombie: Zombie = spawner.spawn(WALKER, 1, RULES)
	zombie.set_physics_process(false)
	zombie.global_position = at
	zombie.state = state
	return zombie


func _kill_info(attacker: Node) -> DamageInfo:
	return DamageInfo.create(10.0, attacker)


func test_pick_for_level() -> void:
	assert_null(FieldAbility.pick_for_level(1), "nothing before level 3")
	assert_null(FieldAbility.pick_for_level(2))
	assert_eq(FieldAbility.pick_for_level(3), SHOCK_PULSE, "Shock Pulse unlocks at level 3")
	var best: AbilityData = FieldAbility.pick_for_level(50)
	for id: StringName in Content.sorted_ids(&"abilities"):
		var data: AbilityData = Content.get_item(&"abilities", id) as AbilityData
		assert_lte(data.unlock_level, best.unlock_level, "level 50 brings the highest unlock")


func test_press_uses_it_once_and_starts_the_cooldown() -> void:
	ability.tick(_press())
	assert_eq(ability.cooldown_left, 60.0)
	ability._physics_process(1.0)
	ability.tick(_press())
	assert_eq(ability.cooldown_left, 59.0, "a press during the cooldown does nothing")
	ability._physics_process(59.0)
	assert_true(ability.can_use(), "ready again after 60 s")


func test_no_press_no_use() -> void:
	ability.tick(InputFrame.new())
	assert_eq(ability.cooldown_left, 0.0)


func test_no_ability_no_use() -> void:
	ability.ability = null
	ability.tick(_press())
	assert_false(ability.use())
	assert_eq(ability.cooldown_left, 0.0)


func test_kill_by_the_user_takes_half_a_second() -> void:
	ability.use()
	Events.enemy_killed.emit(null, _kill_info(player))
	assert_eq(ability.cooldown_left, 59.5)
	var other: Player = PLAYER.instantiate() as Player
	root.add_child(other)
	other.set_physics_process(false)
	Events.enemy_killed.emit(null, _kill_info(other))
	assert_eq(ability.cooldown_left, 59.5, "a teammate's kill does not count")
	ability.cooldown_left = 0.2
	Events.enemy_killed.emit(null, _kill_info(player))
	assert_eq(ability.cooldown_left, 0.0, "never below zero")


func test_gadgeteer_shortens_the_cooldown() -> void:
	player.skill_ranks = {&"gadgeteer": 3}
	player.equip_gear([], false)
	assert_almost_eq(ability.full_cooldown(), 60.0 * 0.76, 0.001, "-8% per rank, 3 ranks")


func test_cooldown_reduction_stops_at_forty_percent() -> void:
	player.skill_ranks = {&"gadgeteer": 3}
	player.equip_gear([], false)
	player.stats.add_modifier(&"ability_cooldown", "increased", 0.3, &"implant")
	assert_almost_eq(ability.full_cooldown(), 36.0, 0.001, "gear plus skill capped at 40%")


func test_downed_or_in_the_hub_cannot_use() -> void:
	player.is_downed = true
	assert_false(ability.use())
	player.is_downed = false
	session.is_hub = true
	assert_false(ability.use())
	session.is_hub = false
	assert_true(ability.use())


func test_shock_pulse_stuns_within_six_metres() -> void:
	var near: Zombie = _zombie(Vector3(5, 0, 0))
	var far: Zombie = _zombie(Vector3(7, 0, 0))
	assert_true(ability.use())
	assert_eq(near.stun_left, 2.0, "5 m away: stunned for 2 s")
	assert_gt(near.velocity.x, 0.0, "pushed away from the user")
	assert_eq(far.stun_left, 0.0, "7 m away: untouched")


func test_stun_runs_out_after_two_seconds() -> void:
	var zombie: Zombie = _zombie(Vector3(2, 0, 0))
	zombie.stun(2.0, Vector3.ZERO)
	zombie._physics_process(1.0)
	assert_gt(zombie.stun_left, 0.0)
	zombie._physics_process(1.0)
	assert_eq(zombie.stun_left, 0.0)


func test_stunned_zombie_cancels_its_swing_and_does_not_attack() -> void:
	player.global_position = Vector3(0.8, 0, 0)
	var zombie: Zombie = _zombie(Vector3(0, 0, 0), Zombie.State.ATTACKING)
	zombie.target = player
	zombie.stun(2.0, Vector3.ZERO)
	assert_eq(zombie.state, Zombie.State.CHASING, "the swing is cancelled")
	var health: float = player.health.current
	for _i: int in 10:
		zombie._physics_process(0.1)
	assert_eq(zombie.state, Zombie.State.CHASING, "no new swing while stunned")
	assert_eq(player.health.current, health)


func test_zombie_at_a_window_is_held_not_pushed() -> void:
	var zombie: Zombie = _zombie(Vector3(2, 0, 0), Zombie.State.ENTERING)
	zombie.stun(2.0, Vector3(6, 0, 0))
	assert_eq(zombie.state, Zombie.State.ENTERING)
	assert_eq(zombie.velocity, Vector3.ZERO, "not pushed off its window")
	zombie._physics_process(0.1)
	assert_eq(zombie.velocity, Vector3.ZERO)


func test_stun_does_not_trip_the_stuck_watch() -> void:
	var zombie: Zombie = _zombie(Vector3(2, 0, 0))
	zombie.target = player
	zombie.stun(2.0, Vector3.ZERO)
	for _i: int in 20:
		zombie._physics_process(0.1)
	assert_eq(zombie._stuck_watch.unreachable_time, 0.0, "standing still while stunned is not stuck")


func test_shock_pulse_without_a_spawner_does_nothing() -> void:
	AbilityEffects.shock_pulse(null, Vector3.ZERO, SHOCK_PULSE)
	assert_eq(ability.cooldown_left, 0.0, "no zombies to stun, no crash")


func test_saved_pick_is_used_only_when_unlocked() -> void:
	assert_eq(FieldAbility.pick_for("shock_pulse", 20).id, &"shock_pulse", "a saved pick is brought")
	assert_eq(FieldAbility.pick_for("adrenal_rush", 20), FieldAbility.pick_for_level(20), "locked: highest unlocked")
	assert_eq(FieldAbility.pick_for("no_such_ability", 20), FieldAbility.pick_for_level(20), "unknown: highest")
	assert_eq(FieldAbility.pick_for("", 3), SHOCK_PULSE)
	assert_null(FieldAbility.pick_for("shock_pulse", 2))

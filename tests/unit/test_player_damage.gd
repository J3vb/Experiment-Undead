## Damage flinch changes aiming, so both kick draws use the match's seeded RNG.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var session: GameSession
var player: Player


func before_each() -> void:
	session = autofree(GameSession.new()) as GameSession
	session.rng.seed = 71
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	player.session = session


func test_damage_uses_two_session_rng_draws_for_flinch() -> void:
	var expected: GameSession = autofree(GameSession.new()) as GameSession
	expected.rng.state = session.rng.state
	expected.rng.randf_range(1.0, 2.5)
	expected.rng.randf_range(-1.0, 1.0)
	var before: int = session.rng.state
	player.take_damage(DamageInfo.create(1.0, null))
	assert_ne(session.rng.state, before, "aiming randomness consumes the session stream")
	assert_eq(session.rng.state, expected.rng.state, "hurt sound pitch does not consume the gameplay stream")
	assert_gt(player.camera_rig._recoil_target.x, 0.0, "damage produces an upward flinch")


func test_damage_aim_replays_from_the_same_session_seed() -> void:
	var kick: Vector2 = Vector2.ZERO
	var aim: Vector3 = Vector3.ZERO
	var final_state: int = 0
	for run: int in 2:
		session.rng.seed = 71
		player.camera_rig._recoil_target = Vector2.ZERO
		player.camera_rig._recoil_current = Vector2.ZERO
		player.take_damage(DamageInfo.create(1.0, null))
		player.camera_rig.update_feel(1.0 / 60.0, false, false, 0.0, player.camera_rig.base_fov, player.walk_speed)
		if run == 0:
			kick = player.camera_rig._recoil_target
			aim = -player.camera.global_basis.z
			final_state = session.rng.state
		else:
			assert_eq(player.camera_rig._recoil_target, kick, "seeded damage repeats pitch and yaw")
			assert_eq(-player.camera.global_basis.z, aim, "hitscan sees the same aim direction")
			assert_eq(session.rng.state, final_state, "later gameplay receives the same random stream")
	assert_ne(aim, Vector3.FORWARD, "the replay assertion includes an actual aiming change")
